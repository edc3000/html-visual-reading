#!/bin/bash
# 跑完全部测试
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
bash "$ROOT/tests/test_build.sh"
bash "$ROOT/tests/test_check.sh"
bash "$ROOT/tests/test_render.sh"
python3 "$ROOT/tests/test_inline_images.py"
python3 "$ROOT/tests/test_layout.py"
echo "全部测试通过"
