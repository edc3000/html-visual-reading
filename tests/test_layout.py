#!/usr/bin/env python3
"""渲染级布局测试：用真实浏览器打开每个 fixture 的构建产物，断言没有
页面级横向溢出、控制台没有 error / pageerror。

test_render.sh 只做字符串快照比对（逐行核对 .expect 文件里的 CSS 片段是否
出现在产物里），测的是"骨架 CSS 有没有变"，不是"body 渲染出来长什么样"——
就算 fixture 被清空成一行 <p>hi</p>，那些断言照样全绿。这个脚本补上真正
渲染一次、量一次 scrollWidth 这一层，用来拦住"某个组件缺了 overflow-wrap
导致长英文串把页面撑宽"这类只有渲染出来才看得见的回归。

Playwright（或它的 chromium）不可用时优雅跳过：打印说明，退出码 0，
不让整组测试因为环境缺依赖而变红。
"""
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIXTURES_DIR = os.path.join(ROOT, 'tests', 'fixtures')
BUILD_SH = os.path.join(ROOT, 'scripts', 'build.sh')
VIEWPORTS = [(375, 900), (880, 900), (1440, 1000)]


def main():
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print('跳过 test_layout：未安装 playwright（pip install playwright && '
              'python3 -m playwright install chromium）')
        return 0

    fixtures = sorted(
        f for f in os.listdir(FIXTURES_DIR)
        if f.startswith('body-') and f.endswith('.html')
    )
    if not fixtures:
        print('跳过 test_layout：tests/fixtures 下没有 body-*.html')
        return 0

    failures = []

    with sync_playwright() as p:
        try:
            browser = p.chromium.launch()
        except Exception as exc:
            print('跳过 test_layout：chromium 启动失败（%s），'
                  '可能未执行 playwright install chromium' % exc)
            return 0

        with tempfile.TemporaryDirectory() as tmp:
            for name in fixtures:
                fixture_path = os.path.join(FIXTURES_DIR, name)
                out_path = os.path.join(tmp, name[:-5] + '.out.html')
                build = subprocess.run(
                    ['bash', BUILD_SH, fixture_path, out_path, '布局测试', '描述'],
                    capture_output=True, text=True)
                if build.returncode != 0:
                    failures.append('%s: build.sh 失败\n%s' %
                                     (name, build.stdout + build.stderr))
                    continue

                for width, height in VIEWPORTS:
                    page = browser.new_page(viewport={'width': width, 'height': height})
                    console_errors = []
                    page_errors = []
                    page.on('console', lambda msg: console_errors.append(msg.text)
                            if msg.type == 'error' else None)
                    page.on('pageerror', lambda exc: page_errors.append(str(exc)))

                    page.goto('file://' + out_path)
                    page.wait_for_timeout(100)

                    scroll_width = page.evaluate('document.documentElement.scrollWidth')
                    client_width = page.evaluate('document.documentElement.clientWidth')

                    # 容许 1px 的取整误差，超过才算真溢出
                    if scroll_width > client_width + 1:
                        failures.append(
                            '%s @ %dpx: 页面横向溢出 scrollWidth=%d > clientWidth=%d'
                            % (name, width, scroll_width, client_width))
                    if console_errors:
                        failures.append('%s @ %dpx: console error: %s'
                                         % (name, width, console_errors))
                    if page_errors:
                        failures.append('%s @ %dpx: pageerror: %s'
                                         % (name, width, page_errors))

                    page.close()

        browser.close()

    if failures:
        print('FAIL test_layout:')
        for f in failures:
            print('  - ' + f)
        return 1

    print('PASS test_layout')
    return 0


if __name__ == '__main__':
    sys.exit(main())
