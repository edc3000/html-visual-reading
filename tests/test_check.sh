#!/bin/bash
# check.sh 静态校验测试
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1"; exit 1; }

good() {
  cat > "$TMP/$1" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>好页面</title></head>
<body><main class="container"><a href="https://example.com">原文</a>
<img src="data:image/png;base64,AAAA"><section id="a"></section>
<section id="b"></section></main><script>var x=1;</script></body></html>
EOF
}

good ok.html
bash "$ROOT/scripts/check.sh" "$TMP/ok.html" || fail "合法页面被判失败"

# 外部资源引用必须被拦
sed 's|src="data:image/png;base64,AAAA"|src="https://cdn.example.com/a.png"|' \
  "$TMP/ok.html" > "$TMP/ext.html"
if bash "$ROOT/scripts/check.sh" "$TMP/ext.html" >/dev/null 2>&1; then
  fail "外部 img src 未被拦截"
fi

# 禁用词必须被拦
sed 's|<title>好页面</title>|<title>TL;DR 页面</title>|' \
  "$TMP/ok.html" > "$TMP/word.html"
if bash "$ROOT/scripts/check.sh" "$TMP/word.html" >/dev/null 2>&1; then
  fail "禁用词未被拦截"
fi

# 重复 id 必须被拦
sed 's|<section id="b">|<section id="a">|' "$TMP/ok.html" > "$TMP/dup.html"
if bash "$ROOT/scripts/check.sh" "$TMP/dup.html" >/dev/null 2>&1; then
  fail "重复 id 未被拦截"
fi

# script 标签不成对必须被拦
sed 's|</script>||' "$TMP/ok.html" > "$TMP/script.html"
if bash "$ROOT/scripts/check.sh" "$TMP/script.html" >/dev/null 2>&1; then
  fail "script 标签不成对未被拦截"
fi

echo "PASS test_check"
