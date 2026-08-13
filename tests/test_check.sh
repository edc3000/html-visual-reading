#!/bin/bash
# check.sh 静态校验测试
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1"; exit 1; }

# 断言 check.sh 真的拦下了问题（退出码非 0），而不是脚本内部崩了个非零退出码
# 冒充"拦住了"——比如变量插值遇到相邻的中文标点导致的 "unbound variable"
# 这类 bash 内部错误，退出码同样非 0，光看退出码测不出来。
assert_rejected() {
  local file="$1" desc="$2"
  local out rc
  out="$(bash "$ROOT/scripts/check.sh" "$file" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || fail "$desc：未被拦截"
  case "$out" in
    *"unbound variable"*) fail "$desc：check.sh 内部报错退出（$out），不是正常拦截" ;;
  esac
  case "$out" in
    *"✗"*) ;;
    *) fail "$desc：退出码非 0 但输出里没有 ✗ 问题行，怀疑是内部报错——$out" ;;
  esac
}

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

# 11. C1：本地相对路径 img（未被内联）必须被拦
cat > "$TMP/img_relative.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main><img src="docs/img/arch.png" alt="架构图"></main><script>var x=1;</script></body></html>
EOF
assert_rejected "$TMP/img_relative.html" "本地相对路径 img（未内联）"

# 12. C1：本地绝对路径 img（未被内联）必须被拦
cat > "$TMP/img_absolute.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main><img src="/Users/x/project/docs/img/arch.png" alt="架构图"></main><script>var x=1;</script></body></html>
EOF
assert_rejected "$TMP/img_absolute.html" "本地绝对路径 img（未内联）"

# 13. C1：data URI 的 img 必须放行（必须通过）
cat > "$TMP/img_data_uri.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main><img src="data:image/png;base64,AAAA" alt="架构图"></main><script>var x=1;</script></body></html>
EOF
bash "$ROOT/scripts/check.sh" "$TMP/img_data_uri.html" >/dev/null 2>&1 || fail "data URI img 被误拦"

# 14. I4：代码块里的 "online = True" 不应被误判为 inline JS 事件属性（必须通过）
cat > "$TMP/false_positive_online.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main><pre><code>online = True</code></pre></main><script>var x=1;</script></body></html>
EOF
bash "$ROOT/scripts/check.sh" "$TMP/false_positive_online.html" >/dev/null 2>&1 || fail "正文 online = True 被误判为 inline JS 事件属性"

# 15. I4：正文提到「把参数 once=true 传进去」不应被误判为 inline JS 事件属性（必须通过）
cat > "$TMP/false_positive_once.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main><p>把参数 once=true 传进去</p></main><script>var x=1;</script></body></html>
EOF
bash "$ROOT/scripts/check.sh" "$TMP/false_positive_once.html" >/dev/null 2>&1 || fail "正文 once=true 被误判为 inline JS 事件属性"

# 16. I4：正文提到「CSS 里的 @import 会引入外部样式表」不应被误判（必须通过）
cat > "$TMP/false_positive_import.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main><p>CSS 里的 <code>@import</code> 会引入外部样式表</p></main><script>var x=1;</script></body></html>
EOF
bash "$ROOT/scripts/check.sh" "$TMP/false_positive_import.html" >/dev/null 2>&1 || fail "正文提及 @import 被误判为 CSS 中存在 @import"

# 17. I4：收紧后，<style> 内真实的 @import 仍必须被拦（回归）
cat > "$TMP/real_import.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title><style>@import url(https://evil.example.com/x.css);</style></head>
<body><main></main><script>var x=1;</script></body></html>
EOF
assert_rejected "$TMP/real_import.html" "<style> 内真实 @import"

# 18. I4：收紧后，onclick 真实事件属性仍必须被拦（回归）
cat > "$TMP/real_onclick.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main><button onclick="x()">按钮</button></main><script>var x=1;</script></body></html>
EOF
assert_rejected "$TMP/real_onclick.html" "onclick 真实事件属性"

# 19. I4：收紧后，onerror 真实事件属性仍必须被拦（回归）
cat > "$TMP/real_onerror.html" <<'EOF'
<!doctype html>
<html lang="zh-CN"><head><title>页面</title></head>
<body><main><img src="data:image/png;base64,AAAA" onerror="y()"></main><script>var x=1;</script></body></html>
EOF
assert_rejected "$TMP/real_onerror.html" "onerror 真实事件属性"

echo "PASS test_check"
