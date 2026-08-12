#!/usr/bin/env python3
"""把 HTML 中的 <img src="..."> 全部替换成内联 data URI。

只依赖标准库与 macOS 自带的 sips。任何单张图片失败都不中断构建：
记录告警、保留原引用、继续处理下一张。
"""
import base64
import itertools
import mimetypes
import os
import re
import subprocess
import sys
import tempfile

MAX_WIDTH = 1600
JPEG_THRESHOLD = 300 * 1024
TOTAL_WARN_BYTES = 5 * 1024 * 1024

IMG_SRC_RE = re.compile(r'(<img\b[^>]*?\bsrc=)(["\'])(.*?)\2', re.IGNORECASE)
_tmp_counter = itertools.count()


def _is_svg(path):
    """检查文件是否为 SVG（扩展名或内容嗅探）。"""
    if os.path.splitext(path)[1].lower() == '.svg':
        return True
    try:
        with open(path, 'rb') as f:
            head = f.read(1024).lstrip()
    except OSError:
        return False
    return (head.startswith(b'<?xml') and b'<svg' in head or
            head.startswith(b'<svg'))


def _looks_like_image(path):
    """检查文件内容是否像图片（magic byte）。只用于校验远程下载的文件。"""
    if _is_svg(path):
        return True
    try:
        with open(path, 'rb') as f:
            head = f.read(16)
    except OSError:
        return False
    if head.startswith(b'\x89PNG\r\n\x1a\n'):
        return True
    if head.startswith(b'\xff\xd8\xff'):
        return True
    if head.startswith(b'GIF87a') or head.startswith(b'GIF89a'):
        return True
    if head.startswith(b'RIFF') and head[8:12] == b'WEBP':
        return True
    if head.startswith(b'BM'):
        return True
    return False


def sips_get(path, key):
    """读取 sips 属性，取不到返回 None（非位图如 SVG 会走到这里）。"""
    try:
        proc = subprocess.run(['sips', '-g', key, path],
                              capture_output=True, text=True)
    except OSError:
        return None
    for line in proc.stdout.splitlines():
        stripped = line.strip()
        if stripped.startswith(key + ':'):
            return stripped.split(':', 1)[1].strip()
    return None


def compress(path, workdir):
    """按需缩放与转码，返回处理后的文件路径（可能就是入参）。"""
    # SVG 不转码，直接返回
    if _is_svg(path):
        return path

    width = sips_get(path, 'pixelWidth')
    if width is None:
        return path

    current = path
    try:
        if int(float(width)) > MAX_WIDTH:
            counter = next(_tmp_counter)
            dst = os.path.join(workdir, '%d_resized_%s' % (counter, os.path.basename(path)))
            subprocess.run(['sips', '--resampleWidth', str(MAX_WIDTH),
                            current, '--out', dst], capture_output=True)
            if os.path.exists(dst) and os.path.getsize(dst) > 0:
                current = dst
    except ValueError:
        pass

    # 转 JPEG 会让透明区域变黑，因此只对不含 alpha 的图做转换
    if (os.path.getsize(current) > JPEG_THRESHOLD
            and sips_get(current, 'hasAlpha') == 'no'):
        counter = next(_tmp_counter)
        base = os.path.splitext(os.path.basename(path))[0]
        dst = os.path.join(workdir, '%d_%s_converted.jpg' % (counter, base))
        subprocess.run(['sips', '-s', 'format', 'jpeg',
                        '-s', 'formatOptions', '80', current, '--out', dst],
                       capture_output=True)
        if os.path.exists(dst) and os.path.getsize(dst) > 0:
            current = dst

    return current


def to_data_uri(path):
    # 内容嗅探优先于扩展名（防止 SVG 内容被错误识别为其他类型）
    if _is_svg(path):
        mime = 'image/svg+xml'
    else:
        mime = mimetypes.guess_type(path)[0]
        if mime is None:
            mime = 'application/octet-stream'
    with open(path, 'rb') as f:
        payload = base64.b64encode(f.read()).decode('ascii')
    return 'data:%s;base64,%s' % (mime, payload)


def resolve_local(src, base_dir):
    """把 src 解析成本地文件路径，解析不到返回 None。"""
    if os.path.isabs(src):
        return src if os.path.isfile(src) else None
    candidate = os.path.join(base_dir, src)
    return candidate if os.path.isfile(candidate) else None


def fetch_remote(url, workdir, warnings):
    """用 curl 下载远程图片，失败返回 None。"""
    # 剥掉查询串和片段
    url_base = url.split('?')[0].split('#')[0]
    suffix = os.path.splitext(url_base)[1] or '.img'
    counter = next(_tmp_counter)
    dst = os.path.join(workdir, 'remote_%d%s' % (counter, suffix))
    try:
        proc = subprocess.run(
            ['curl', '-sSL', '--max-time', '20', '--fail', '-o', dst, url],
            capture_output=True, text=True)
    except OSError as exc:
        warnings.append('curl 不可用，保留原引用: %s (%s)' % (url, exc))
        return None
    if proc.returncode != 0:
        # curl 失败，提取 stderr 首行（如有）
        error_detail = (proc.stderr.splitlines()[0] if proc.stderr else '') or '未知原因'
        warnings.append('远程图片下载失败，保留原引用: %s (%s)' % (url, error_detail))
        return None
    if not os.path.exists(dst) or os.path.getsize(dst) == 0:
        warnings.append('远程图片下载失败，保留原引用: %s' % url)
        return None
    # 校验内容像不像图片
    if not _looks_like_image(dst):
        warnings.append('远程内容不像图片（可能是 HTML 错误页），保留原引用: %s' % url)
        return None
    return dst


def fetch(src, base_dir, workdir, warnings):
    """返回可读的本地文件路径；失败返回 None 并写入告警。"""
    if src.startswith('http://') or src.startswith('https://'):
        return fetch_remote(src, workdir, warnings)
    local = resolve_local(src, base_dir)
    if local is None:
        warnings.append('图片不存在，保留原引用: %s' % src)
        return None
    return local


def process(html, base_dir, workdir):
    """返回 (替换后的 html, [(src, 字节数)], [告警])。"""
    inlined = []
    warnings = []
    matched_count = 0

    def replace(match):
        nonlocal matched_count
        matched_count += 1
        prefix = match.group(1)  # <img...src=
        src = match.group(3)     # 内容
        if src.startswith('data:'):
            return match.group(0)
        path = fetch(src, base_dir, workdir, warnings)
        if path is None:
            return match.group(0)
        try:
            compressed = compress(path, workdir)
            uri = to_data_uri(compressed)
        except (OSError, ValueError) as exc:
            warnings.append('图片处理失败，保留原引用: %s (%s)' % (src, exc))
            return match.group(0)
        inlined.append((src, len(uri)))
        # 统一输出为双引号
        return prefix + '"' + uri + '"'

    result = IMG_SRC_RE.sub(replace, html)

    # 检查是否有 img 标签没被正则匹配到
    total_tags = len(re.findall(r'<img\b', html, re.IGNORECASE))
    if total_tags > matched_count:
        warnings.append('有 %d 个 <img> 标签的 src 无法解析，产物可能残留外部引用'
                       % (total_tags - matched_count))

    return result, inlined, warnings


def report(inlined):
    """生成体积报告行。总量超阈值时列出最大的 5 张。"""
    total = sum(size for _, size in inlined)
    lines = ['已内联 %d 张图片，合计 %.1f MB' % (len(inlined), total / 1048576.0)]
    if total > TOTAL_WARN_BYTES:
        lines.append('警告: 图片总体积超过 %d MB，考虑删减以下几张'
                     % (TOTAL_WARN_BYTES // 1048576))
        for src, size in sorted(inlined, key=lambda item: -item[1])[:5]:
            lines.append('  %.1f MB  %s' % (size / 1048576.0, src))
    return lines


def main(argv):
    if len(argv) < 3:
        print('用法: inline_images.py <in.html> <out.html> [--base-dir <dir>]',
              file=sys.stderr)
        return 1

    src_path, dst_path = argv[1], argv[2]
    base_dir = os.path.dirname(os.path.abspath(src_path))
    if '--base-dir' in argv:
        base_dir = argv[argv.index('--base-dir') + 1]

    with open(src_path, encoding='utf-8') as f:
        html = f.read()

    workdir = tempfile.mkdtemp()
    result, inlined, warnings = process(html, base_dir, workdir)

    with open(dst_path, 'w', encoding='utf-8') as f:
        f.write(result)

    for warning in warnings:
        print('警告: ' + warning, file=sys.stderr)

    for line in report(inlined):
        print(line)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
