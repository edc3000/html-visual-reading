#!/bin/bash
# 对产出的 HTML 做静态校验。任一项不通过即退出码 1。
set -uo pipefail

FILE="${1:-}"
[ -s "$FILE" ] || { echo "错误: 文件不存在或为空: $FILE" >&2; exit 1; }

PROBLEMS=0
report() { echo "✗ $1"; PROBLEMS=$((PROBLEMS + 1)); }

# 1. 外部资源引用（指向原文的 <a href> 是允许的，只查资源）
# 违规资源属性（大小写不敏感）：src、srcset、link href、url()
# 放行导航：<a href>

# 检查 src="http..." 或 src='http...'（大小写不敏感，排除 data: URI）
if grep -iqE '[[:space:]]src=["'"'"']https?://' "$FILE"; then
  report "存在外部资源 src"
fi

# 检查 srcset="http..." 或 srcset='http...'（大小写不敏感）
if grep -iqE '[[:space:]]srcset=["'"'"'].*https?://' "$FILE"; then
  report "存在外部资源 srcset"
fi

# 检查 <link> 标签指向 http... （大小写不敏感，避免误伤 <a href>）
if grep -iqE '<link[^>]+href=["'"'"']https?://' "$FILE"; then
  report "存在外部样式表 link"
fi

# 检查 url(http...) 或 url('http...') 或 url("http...") 在 style 或 <style> 中
if grep -iqE 'url\(["'"'"']?https?://' "$FILE"; then
  report "存在外部资源 url()"
fi

# 检查 @import（大小写不敏感）
if grep -iqE '@import' "$FILE"; then
  report "CSS 中存在 @import"
fi

# 2. 禁用词
for word in 'TL;DR' '太长不看' '综上所述' '笔者认为' '众所周知' '不言而喻'; do
  if grep -qF "$word" "$FILE"; then report "出现禁用词: $word"; fi
done

# 3. 标签配对与唯一性
OPEN=$(grep -o '<script' "$FILE" | wc -l | tr -d ' ')
CLOSE=$(grep -o '</script>' "$FILE" | wc -l | tr -d ' ')
[ "$OPEN" = "$CLOSE" ] || report "script 标签不成对（$OPEN 开 / $CLOSE 闭）"

for tag in '<!doctype html>' '<html' '<main'; do
  COUNT=$(grep -oiF "$tag" "$FILE" | wc -l | tr -d ' ')
  [ "$COUNT" -le 1 ] || report "$tag 出现 $COUNT 次，应至多 1 次"
done

# 4. DOM id 唯一（需要真正的 id= 属性，不能误判 data-testid 等）
# 提取所有 id="..." 或 id='...' 的属性值（空白边界）
DUP=$(grep -oE '[[:space:]]id=["'"'"'][^"'"'"']*["'"'"']' "$FILE" | \
      sed -e 's/^[[:space:]]*id=["'"'"']//' -e 's/["'"'"']$//' | \
      sort | uniq -d)
[ -z "$DUP" ] || report "存在重复 id: $(echo "$DUP" | tr '\n' ' ')"

# 5. body 中不得有 inline JS 事件属性（所有 on* 事件，大小写不敏感）
# 匹配空白边界，后跟 on + 字母序列 + 空格/等号，大小写不敏感
if grep -iqE '[[:space:]]on[a-z]+[[:space:]]*=' "$FILE"; then
  report "存在 inline JS 事件属性"
fi

if [ "$PROBLEMS" -gt 0 ]; then
  echo "静态检查未通过，共 $PROBLEMS 项问题" >&2
  exit 1
fi
echo "检查通过"
