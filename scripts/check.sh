#!/bin/bash
# 对产出的 HTML 做静态校验。任一项不通过即退出码 1。
set -uo pipefail

FILE="${1:-}"
[ -s "$FILE" ] || { echo "错误: 文件不存在或为空: $FILE" >&2; exit 1; }

PROBLEMS=0
report() { echo "✗ $1"; PROBLEMS=$((PROBLEMS + 1)); }

# 1. 外部资源引用（指向原文的 <a href> 是允许的，只查资源）
if grep -qE '(src|href)="https?://[^"]*\.(css|js|png|jpe?g|gif|svg|webp|woff2?)' "$FILE"; then
  report "存在外部资源引用"
fi
if grep -qE '<link[^>]+stylesheet' "$FILE"; then report "存在外部样式表 link"; fi
if grep -q '@import' "$FILE"; then report "CSS 中存在 @import"; fi
if grep -qE '<img[^>]+src="https?://' "$FILE"; then report "存在未内联的远程 img"; fi

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

# 4. DOM id 唯一
DUP=$(grep -o 'id="[^"]*"' "$FILE" | sort | uniq -d)
[ -z "$DUP" ] || report "存在重复 id: $(echo "$DUP" | tr '\n' ' ')"

# 5. body 中不得有 inline JS
if grep -qE '\son(click|change|input|mouseover)="' "$FILE"; then
  report "存在 inline JS 事件属性"
fi

if [ "$PROBLEMS" -gt 0 ]; then
  echo "静态检查未通过，共 $PROBLEMS 项问题" >&2
  exit 1
fi
echo "检查通过"
