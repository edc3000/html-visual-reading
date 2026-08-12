#!/usr/bin/env python3
"""inline_images.py 的单元测试（标准库 unittest，无第三方依赖）。"""
import os
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))

import inline_images as ii


def make_png(path, width, height, alpha=False, noise=False):
    """生成一张真实可解析的 PNG，避免依赖外部素材。

    noise=True 用高熵随机数据填充，zlib 压不动，因此小尺寸也能稳定
    超过 300KB 的转码阈值。noise=False 用重复行，压缩率高、体积小。
    两种都按行切片拼接，不逐像素循环——逐像素在 500x500 就要跑几十秒。
    """
    channels = 4 if alpha else 3
    color_type = 6 if alpha else 2
    if noise:
        body = os.urandom(width * height * channels)
    else:
        row = bytes([(x * 7) % 256 for x in range(width * channels)])
        body = row * height

    stride = width * channels
    raw = b''.join(b'\x00' + body[y * stride:(y + 1) * stride]
                   for y in range(height))

    def chunk(tag, data):
        payload = tag + data
        return (struct.pack('>I', len(data)) + payload
                + struct.pack('>I', zlib.crc32(payload) & 0xffffffff))

    out = b'\x89PNG\r\n\x1a\n'
    out += chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8,
                                      color_type, 0, 0, 0))
    out += chunk(b'IDAT', zlib.compress(raw))
    out += chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(out)


class InlineLocalTest(unittest.TestCase):

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.work = tempfile.mkdtemp()

    def test_local_png_becomes_data_uri(self):
        img = os.path.join(self.tmp, 'fig.png')
        make_png(img, 40, 20, alpha=False)
        html = '<img src="fig.png" alt="x">'
        out, inlined, warnings = ii.process(html, self.tmp, self.work)
        self.assertIn('src="data:image/', out)
        self.assertNotIn('src="fig.png"', out)
        self.assertEqual(len(inlined), 1)
        self.assertEqual(warnings, [])

    def test_existing_data_uri_untouched(self):
        html = '<img src="data:image/png;base64,AAAA">'
        out, inlined, warnings = ii.process(html, self.tmp, self.work)
        self.assertEqual(out, html)
        self.assertEqual(inlined, [])

    def test_missing_file_warns_and_keeps_src(self):
        html = '<img src="nope.png">'
        out, inlined, warnings = ii.process(html, self.tmp, self.work)
        self.assertIn('src="nope.png"', out)
        self.assertEqual(len(warnings), 1)

    def test_wide_image_is_resampled(self):
        img = os.path.join(self.tmp, 'wide.png')
        make_png(img, 2000, 100, alpha=False)
        result = ii.compress(img, self.work)
        self.assertEqual(ii.sips_get(result, 'pixelWidth'), '1600')

    def test_alpha_png_not_converted_to_jpeg(self):
        # 500x500 噪声图约 977KB，宽度未过 1600 所以不触发缩放，
        # 直接检验「超阈值但含 alpha 时不得转 JPEG」这条规则
        img = os.path.join(self.tmp, 'alpha.png')
        make_png(img, 500, 500, alpha=True, noise=True)
        self.assertGreater(os.path.getsize(img), 300 * 1024)
        result = ii.compress(img, self.work)
        self.assertEqual(ii.sips_get(result, 'hasAlpha'), 'yes')
        self.assertFalse(result.endswith('.jpg'))

    def test_opaque_large_png_converted_to_jpeg(self):
        # 同尺寸不透明噪声图约 733KB，应当被转成 JPEG
        img = os.path.join(self.tmp, 'big.png')
        make_png(img, 500, 500, alpha=False, noise=True)
        self.assertGreater(os.path.getsize(img), 300 * 1024)
        result = ii.compress(img, self.work)
        self.assertTrue(result.endswith('.jpg'))

    def test_cli_writes_output(self):
        img = os.path.join(self.tmp, 'fig.png')
        make_png(img, 30, 30, alpha=False)
        src = os.path.join(self.tmp, 'in.html')
        dst = os.path.join(self.tmp, 'out.html')
        with open(src, 'w', encoding='utf-8') as f:
            f.write('<img src="fig.png">')
        subprocess.check_call(
            [sys.executable, os.path.join(ROOT, 'scripts', 'inline_images.py'),
             src, dst])
        with open(dst, encoding='utf-8') as f:
            self.assertIn('data:image/', f.read())

    def test_svg_not_converted(self):
        # 构造一个超过 300KB 的 SVG（包含大量注释）
        svg_path = os.path.join(self.tmp, 'big.svg')
        svg_content = b'<?xml version="1.0"?>\n<svg xmlns="http://www.w3.org/2000/svg">\n'
        svg_content += b'<!-- ' + (b'x' * 310000) + b' -->\n'
        svg_content += b'<circle cx="50" cy="50" r="40" />\n</svg>'
        with open(svg_path, 'wb') as f:
            f.write(svg_content)
        self.assertGreater(os.path.getsize(svg_path), 300 * 1024)
        # compress() 应原样返回 SVG 路径
        result = ii.compress(svg_path, self.work)
        self.assertEqual(result, svg_path)
        # process() 应产生 SVG data URI，不是 JPEG
        html = '<img src="big.svg">'
        out, inlined, warnings = ii.process(html, self.tmp, self.work)
        self.assertIn('data:image/svg+xml;base64,', out)
        self.assertEqual(warnings, [])

    def test_single_quoted_src_inlined(self):
        img = os.path.join(self.tmp, 'fig.png')
        make_png(img, 40, 20, alpha=False)
        html = "<img src='fig.png' alt='x'>"
        out, inlined, warnings = ii.process(html, self.tmp, self.work)
        self.assertIn('src="data:image/', out)
        self.assertNotIn("src='fig.png'", out)
        self.assertEqual(len(inlined), 1)

    def test_unquoted_src_warns(self):
        img = os.path.join(self.tmp, 'fig.png')
        make_png(img, 40, 20, alpha=False)
        html = '<img src=fig.png>'
        out, inlined, warnings = ii.process(html, self.tmp, self.work)
        # 正则应匹配不到无引号的 src，产生告警
        self.assertEqual(len(inlined), 0)
        # 应该有关于未解析 img 的告警
        self.assertTrue(any('img' in w.lower() and '无法解析' in w
                           for w in warnings),
                       'Expected warning about unparseable img tags')

    def test_svg_with_wrong_extension(self):
        # SVG 内容但扩展名错误（.png），to_data_uri 应识别内容而非文件名
        svg_path = os.path.join(self.tmp, 'chart.png')  # 注意：.png 后缀
        svg_content = b'<?xml version="1.0"?>\n<svg xmlns="http://www.w3.org/2000/svg">\n'
        svg_content += b'<circle cx="50" cy="50" r="40" />\n</svg>'
        with open(svg_path, 'wb') as f:
            f.write(svg_content)
        # process() 应正确识别为 SVG，产生 SVG data URI 而非 PNG
        html = '<img src="chart.png">'
        out, inlined, warnings = ii.process(html, self.tmp, self.work)
        self.assertIn('data:image/svg+xml;base64,', out)
        self.assertNotIn('data:image/png;base64,', out)
        self.assertEqual(len(inlined), 1)
        self.assertEqual(warnings, [])


import http.server
import threading


class RemoteImageTest(unittest.TestCase):
    """用本地 http server 验证远程抓取，不依赖外网。"""

    @classmethod
    def setUpClass(cls):
        cls.serve_dir = tempfile.mkdtemp()
        make_png(os.path.join(cls.serve_dir, 'remote.png'), 60, 40, alpha=False)
        # 创建伪造的图片——返回 200 但内容是 HTML
        with open(os.path.join(cls.serve_dir, 'fake.png'), 'w') as f:
            f.write('<html><body><h1>404 Not Found</h1></body></html>')

        handler = http.server.SimpleHTTPRequestHandler
        directory = cls.serve_dir

        class Handler(handler):
            def __init__(self, *args, **kwargs):
                super().__init__(*args, directory=directory, **kwargs)

            def log_message(self, *args):
                pass

        cls.httpd = http.server.HTTPServer(('127.0.0.1', 0), Handler)
        cls.port = cls.httpd.server_address[1]
        cls.thread = threading.Thread(target=cls.httpd.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()
        cls.httpd.server_close()

    def test_remote_image_inlined(self):
        work = tempfile.mkdtemp()
        html = '<img src="http://127.0.0.1:%d/remote.png">' % self.port
        out, inlined, warnings = ii.process(html, work, work)
        self.assertIn('src="data:image/', out)
        self.assertEqual(len(inlined), 1)
        self.assertEqual(warnings, [])

    def test_unreachable_remote_warns_and_keeps_src(self):
        work = tempfile.mkdtemp()
        url = 'http://127.0.0.1:%d/missing.png' % self.port
        html = '<img src="%s">' % url
        out, inlined, warnings = ii.process(html, work, work)
        self.assertIn(url, out)
        self.assertEqual(inlined, [])
        self.assertEqual(len(warnings), 1)

    def test_fake_image_content_warns_and_keeps_src(self):
        work = tempfile.mkdtemp()
        url = 'http://127.0.0.1:%d/fake.png' % self.port
        html = '<img src="%s">' % url
        out, inlined, warnings = ii.process(html, work, work)
        # 200 响应但内容是 HTML，应产生告警并保留原引用
        self.assertIn(url, out)
        self.assertEqual(inlined, [])
        self.assertEqual(len(warnings), 1)
        self.assertIn('内容', warnings[0])


class ReportTest(unittest.TestCase):

    def test_report_under_threshold_has_no_warning(self):
        lines = ii.report([('a.png', 1000), ('b.png', 2000)])
        self.assertEqual(len(lines), 1)
        self.assertIn('2 张', lines[0])

    def test_report_over_threshold_lists_largest(self):
        # 6 张图，体积从大到小：6MB, 5MB, 4MB, 3MB, 2MB, 1MB
        # 乱序传入以验证排序逻辑
        big = [
            ('img_small.png', 1 * 1024 * 1024),
            ('img_huge.png', 6 * 1024 * 1024),
            ('img_large.png', 5 * 1024 * 1024),
            ('img_medium.png', 3 * 1024 * 1024),
            ('img_mediumlarge.png', 4 * 1024 * 1024),
            ('img_mediummid.png', 2 * 1024 * 1024),
        ]
        lines = ii.report(big)
        joined = '\n'.join(lines)
        self.assertIn('超过', joined)
        # 应列出最大的 5 张：img_huge, img_large, img_mediumlarge, img_medium, img_mediummid
        self.assertIn('img_huge.png', joined)
        self.assertIn('img_large.png', joined)
        self.assertIn('img_mediumlarge.png', joined)
        self.assertIn('img_medium.png', joined)
        self.assertIn('img_mediummid.png', joined)
        # 最小的不应出现在明细里
        self.assertNotIn('img_small.png', joined)
        # 只列最大的 5 张：1 行汇总 + 1 行告警 + 5 行明细
        self.assertEqual(len(lines), 7)


if __name__ == '__main__':
    unittest.main()
