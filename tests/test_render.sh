#!/bin/bash
# 端到端渲染测试：每个 fixture 构建后，逐行核对同名 .expect 中的断言
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1"; exit 1; }

for FIXTURE in "$ROOT"/tests/fixtures/body-*.html; do
  NAME="$(basename "$FIXTURE" .html)"
  OUT="$TMP/$NAME.html"
  "$ROOT/scripts/build.sh" "$FIXTURE" "$OUT" "渲染测试" "描述" \
    > "$TMP/$NAME.log" 2>&1 || { cat "$TMP/$NAME.log"; fail "$NAME 构建失败"; }

  EXPECT="$ROOT/tests/fixtures/$NAME.expect"
  [ -f "$EXPECT" ] || fail "$NAME 缺少断言文件 $EXPECT"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    grep -qF -- "$line" "$OUT" || fail "$NAME 缺少: $line"
  done < "$EXPECT"

  echo "  ok: $NAME"
done

echo "PASS test_render"
