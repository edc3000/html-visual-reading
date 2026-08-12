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


if __name__ == '__main__':
    unittest.main()
