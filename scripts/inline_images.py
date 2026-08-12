#!/usr/bin/env python3
"""把 HTML 中的 <img src="..."> 全部替换成内联 data URI。

只依赖标准库与 macOS 自带的 sips。任何单张图片失败都不中断构建：
记录告警、保留原引用、继续处理下一张。
"""
import base64
import mimetypes
import os
import re
import subprocess
import sys
import tempfile

MAX_WIDTH = 1600
JPEG_THRESHOLD = 300 * 1024
TOTAL_WARN_BYTES = 5 * 1024 * 1024

IMG_SRC_RE = re.compile(r'(<img\b[^>]*?\bsrc=")([^"]+)(")', re.IGNORECASE)


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
    width = sips_get(path, 'pixelWidth')
    if width is None:
        return path

    current = path
    try:
        if int(width) > MAX_WIDTH:
            dst = os.path.join(workdir, 'resized_' + os.path.basename(path))
            subprocess.run(['sips', '--resampleWidth', str(MAX_WIDTH),
                            current, '--out', dst], capture_output=True)
            if os.path.exists(dst) and os.path.getsize(dst) > 0:
                current = dst
    except ValueError:
        pass

    # 转 JPEG 会让透明区域变黑，因此只对不含 alpha 的图做转换
    if (os.path.getsize(current) > JPEG_THRESHOLD
            and sips_get(current, 'hasAlpha') == 'no'):
        base = os.path.splitext(os.path.basename(path))[0]
        dst = os.path.join(workdir, base + '_converted.jpg')
        subprocess.run(['sips', '-s', 'format', 'jpeg',
                        '-s', 'formatOptions', '80', current, '--out', dst],
                       capture_output=True)
        if os.path.exists(dst) and os.path.getsize(dst) > 0:
            current = dst

    return current


def to_data_uri(path):
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


def fetch(src, base_dir, workdir, warnings):
    """返回可读的本地文件路径；失败返回 None 并写入告警。

    Task 3 会在此扩展远程 URL 支持。
    """
    local = resolve_local(src, base_dir)
    if local is None:
        warnings.append('图片不存在，保留原引用: %s' % src)
        return None
    return local


def process(html, base_dir, workdir):
    """返回 (替换后的 html, [(src, 字节数)], [告警])。"""
    inlined = []
    warnings = []

    def replace(match):
        prefix, src, suffix = match.group(1), match.group(2), match.group(3)
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
        return prefix + uri + suffix

    return IMG_SRC_RE.sub(replace, html), inlined, warnings


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

    total = sum(size for _, size in inlined)
    print('已内联 %d 张图片，合计 %.1f MB' % (len(inlined), total / 1048576.0))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
