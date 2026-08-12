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

# 新增测试用例（对抗性）

# 1. 大写 LINK 标签必须被拦
cat > "$TMP/link_upper.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title><LINK REL="Stylesheet" HREF="https://cdn.example.com/style.css"></head>
<body><main></main><script>var x=1;</script></body></html>
EOF
if bash "$ROOT/scripts/check.sh" "$TMP/link_upper.html" >/dev/null 2>&1; then
  fail "大写 LINK 标签未被拦截"
fi

# 2. 无扩展名的远程脚本必须被拦
cat > "$TMP/script_noext.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main></main><script src="https://analytics.example.com/track"></script></body></html>
EOF
if bash "$ROOT/scripts/check.sh" "$TMP/script_noext.html" >/dev/null 2>&1; then
  fail "无扩展名远程脚本未被拦截"
fi

# 3. srcset 中的外部图片必须被拦
cat > "$TMP/srcset.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main><img srcset="https://cdn.example.com/big.jpg 2x"></main><script>var x=1;</script></body></html>
EOF
if bash "$ROOT/scripts/check.sh" "$TMP/srcset.html" >/dev/null 2>&1; then
  fail "srcset 中的外部图片未被拦截"
fi

# 4. style 中的 url() 必须被拦
cat > "$TMP/style_url.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main><div style="background:url(https://cdn.example.com/bg.png)">内容</div></main><script>var x=1;</script></body></html>
EOF
if bash "$ROOT/scripts/check.sh" "$TMP/style_url.html" >/dev/null 2>&1; then
  fail "style 中的 url() 未被拦截"
fi

# 5. onerror 事件必须被拦
cat > "$TMP/onerror.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main><img src="data:image/png;base64,AAAA" onerror="alert(1)"></main><script>var x=1;</script></body></html>
EOF
if bash "$ROOT/scripts/check.sh" "$TMP/onerror.html" >/dev/null 2>&1; then
  fail "onerror 事件未被拦截"
fi

# 6. 大写 ONCLICK 必须被拦
cat > "$TMP/onclick_upper.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main><button ONCLICK="doThing()">按钮</button></main><script>var x=1;</script></body></html>
EOF
if bash "$ROOT/scripts/check.sh" "$TMP/onclick_upper.html" >/dev/null 2>&1; then
  fail "大写 ONCLICK 事件未被拦截"
fi

# 7. data-testid 不应误判为重复 id（必须通过）
cat > "$TMP/data_id.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main><section id="intro"></section><section data-testid="intro"></section></main><script>var x=1;</script></body></html>
EOF
bash "$ROOT/scripts/check.sh" "$TMP/data_id.html" >/dev/null 2>&1 || fail "data-testid 被误判为重复 id"

# 8. a href 指向数据文件应放行（.json 导航链接）（必须通过）
cat > "$TMP/link_json.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main><a href="https://example.com/report.json">数据</a></main><script>var x=1;</script></body></html>
EOF
bash "$ROOT/scripts/check.sh" "$TMP/link_json.html" >/dev/null 2>&1 || fail "a href 导航链接被误拦"

# 9. srcset 本地 + 同一行的 a href 外链应放行（测试边界匹配）（必须通过）
cat > "$TMP/srcset_local_link.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main><img srcset="local1.jpg 1x, local2.jpg 2x"> <a href="https://arxiv.org/abs/1234">原文</a></main><script>var x=1;</script></body></html>
EOF
bash "$ROOT/scripts/check.sh" "$TMP/srcset_local_link.html" >/dev/null 2>&1 || fail "srcset 本地+外链 a href 被误判"

# 10. srcset 真的外部图片必须被拦（确认收紧后真违规还能拦）
cat > "$TMP/srcset_ext.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main><img srcset="https://cdn.example.com/big.jpg 2x"></main><script>var x=1;</script></body></html>
EOF
if bash "$ROOT/scripts/check.sh" "$TMP/srcset_ext.html" >/dev/null 2>&1; then
  fail "srcset 真外部图片未被拦截"
fi

echo "PASS test_check"
