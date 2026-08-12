#!/bin/bash
# build.sh 拼装与占位替换测试
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1"; exit 1; }

cat > "$TMP/body.html" <<'EOF'
<main class="container"><h1>可见标题</h1></main>
EOF

"$ROOT/scripts/build.sh" "$TMP/body.html" "$TMP/out.html" "标签页标题" "页面描述" \
  || fail "build.sh 退出码非 0"

[ -s "$TMP/out.html" ] || fail "产物为空"
grep -q '<title>标签页标题</title>' "$TMP/out.html" || fail "标题未替换"
grep -q 'content="页面描述"' "$TMP/out.html" || fail "描述未替换"
grep -q '可见标题' "$TMP/out.html" || fail "body 未拼入"
if grep -q '__TITLE__\|__DESCRIPTION__' "$TMP/out.html"; then fail "占位符残留"; fi
if [ "$(grep -c '<!doctype html>' "$TMP/out.html")" -ne 1 ]; then fail "doctype 不唯一"; fi

"$ROOT/scripts/build.sh" "$TMP/body.html" "$TMP/esc.html" 'A & "B" <C>' 'D & "E" <F>' \
  || fail "转义用例构建失败"
grep -q '<title>A &amp; &quot;B&quot; &lt;C&gt;</title>' "$TMP/esc.html" \
  || fail "标题未正确转义"
grep -q 'content="D &amp; &quot;E&quot; &lt;F&gt;"' "$TMP/esc.html" \
  || fail "描述未正确转义"

# body 不存在时必须失败
if "$ROOT/scripts/build.sh" "$TMP/nope.html" "$TMP/x.html" "t" "d" 2>/dev/null; then
  fail "缺失 body 时应退出码 1"
fi

echo "PASS test_build"
