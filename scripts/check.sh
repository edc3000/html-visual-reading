#!/bin/bash
# 对产出的 HTML 做静态校验。任一项不通过即退出码 1。
set -uo pipefail

FILE="${1:-}"
[ -s "$FILE" ] || { echo "错误: 文件不存在或为空: $FILE" >&2; exit 1; }

PROBLEMS=0
report() { echo "✗ $1"; PROBLEMS=$((PROBLEMS + 1)); }

# 返回匹配 $1（扩展正则，大小写不敏感）的行号，逗号分隔，供 report() 定位问题
lines_for() {
  grep -nioE "$1" "$FILE" | cut -d: -f1 | sort -un | paste -sd, -
}

# 1. 外部资源引用（指向原文的 <a href> 是允许的，只查资源）
# 违规资源属性（大小写不敏感）：src、srcset、link href、url()
# 放行导航：<a href>

# 检查 src="http..." 或 src='http...'（大小写不敏感，排除 data: URI）
L=$(lines_for '[[:space:]]src=["'"'"']https?://')
[ -n "$L" ] && report "存在外部资源 src（行 ${L}）"

# 检查 srcset="http..." 或 srcset='http...'（大小写不敏感，用反向引用锁住属性值边界）
L=$(lines_for '[[:space:]]srcset=(["'"'"'])[^"'"'"']*https?://[^"'"'"']*\1')
[ -n "$L" ] && report "存在外部资源 srcset（行 ${L}）"

# 检查 <link> 标签指向 http... （大小写不敏感，避免误伤 <a href>）
L=$(lines_for '<link[^>]+href=["'"'"']https?://')
[ -n "$L" ] && report "存在外部样式表 link（行 ${L}）"

# 检查 url(http...) 或 url('http...') 或 url("http...") 在 style 或 <style> 中
L=$(lines_for 'url\(["'"'"']?https?://')
[ -n "$L" ] && report "存在外部资源 url()（行 ${L}）"

# 检查 @import：只在 <style> 内查。收窄到 <style> 块内是因为正文经常会
# *提到*「@import」这个词本身（讲 CSS 机制的说明文字、代码块里的例句），
# 那种上下文不构成真实风险；真正有风险的只有实际生效样式表里的 @import。
IMPORT_LINES=$(awk '
  tolower($0) ~ /<style/  { f=1 }
  f && tolower($0) ~ /@import/ { print NR }
  tolower($0) ~ /<\/style>/ { f=0 }
' "$FILE" | paste -sd, -)
[ -n "$IMPORT_LINES" ] && report "CSS 中存在 @import（<style> 内，行 ${IMPORT_LINES}）"

# img 的 src 到这一步必须已经是 data: URI。build.sh 会先用 inline_images.py
# 把 body 引用的每张图转成 data URI 再送来这里检查；如果还有 img src 不是
# data: 开头，说明要么是外链没被上面的规则拦到、要么是本地相对/绝对路径没
# 解析到文件（inline_images.py 遇到这种情况只告警、不中断构建，产物里会
# 悄悄留下一张打不开的图）。不存在合法例外，一律拦下。
IMG_BAD_LINES=""
while IFS= read -r entry; do
  lineno="${entry%%:*}"
  tagtext="${entry#*:}"
  raw=$(printf '%s' "$tagtext" | grep -oiE 'src=("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]>]+)' | head -1)
  val=$(printf '%s' "$raw" | sed -e 's/^[sS][rR][cC]=//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//")
  if [ -n "$val" ] && [[ "$val" != data:* ]]; then
    IMG_BAD_LINES="$IMG_BAD_LINES $lineno"
  fi
done < <(grep -noiE '<img\b[^>]*>' "$FILE")
[ -n "$IMG_BAD_LINES" ] && report "图片未内联为 data URI，可能是本地路径解析失败或外链下载失败（行${IMG_BAD_LINES}）"

# 2. 禁用词
for word in 'TL;DR' '太长不看' '综上所述' '笔者认为' '众所周知' '不言而喻'; do
  L=$(grep -nF -- "$word" "$FILE" | cut -d: -f1 | paste -sd, -)
  [ -n "$L" ] && report "出现禁用词: ${word}（行 ${L}）"
done

# 3. 标签配对与唯一性
OPEN=$(grep -o '<script' "$FILE" | wc -l | tr -d ' ')
CLOSE=$(grep -o '</script>' "$FILE" | wc -l | tr -d ' ')
[ "$OPEN" = "$CLOSE" ] || report "script 标签不成对（$OPEN 开 / $CLOSE 闭）"

for tag in '<!doctype html>' '<html' '<main'; do
  COUNT=$(grep -oiF "$tag" "$FILE" | wc -l | tr -d ' ')
  if [ "$COUNT" -gt 1 ]; then
    L=$(grep -nioF -- "$tag" "$FILE" | cut -d: -f1 | paste -sd, -)
    report "${tag} 出现 $COUNT 次，应至多 1 次（行 ${L}）"
  fi
done

# 4. DOM id 唯一（需要真正的 id= 属性，不能误判 data-testid 等）
# 提取所有 id="..." 或 id='...' 的属性值（空白边界）
DUP=$(grep -oE '[[:space:]]id=["'"'"'][^"'"'"']*["'"'"']' "$FILE" | \
      sed -e 's/^[[:space:]]*id=["'"'"']//' -e 's/["'"'"']$//' | \
      sort | uniq -d)
if [ -n "$DUP" ]; then
  while IFS= read -r id; do
    [ -z "$id" ] && continue
    L=$(grep -nE "[[:space:]]id=[\"']${id}[\"']" "$FILE" | cut -d: -f1 | paste -sd, -)
    report "存在重复 id: ${id}（行 ${L}）"
  done <<< "$DUP"
fi

# 5. body 中不得有 inline JS 事件属性（所有 on* 事件，大小写不敏感）
# 只在"标签属性位置"匹配：先把每个开标签整体抽出来，再在标签内部找
# on*= 属性，避免匹配到正文里 "online"、"once=true" 这类普通英文词——
# 旧规则只看"空白 + on字母 + ="这个裸子串，逮住了任何以 on 开头、后跟
# = 的英文单词，不管它是不是真的在标签属性位置上。
ON_LINES=""
while IFS= read -r entry; do
  lineno="${entry%%:*}"
  tagtext="${entry#*:}"
  if printf '%s' "$tagtext" | grep -qE '[[:space:]]on[a-zA-Z]+[[:space:]]*=' -i; then
    ON_LINES="$ON_LINES $lineno"
  fi
done < <(grep -noiE '<[a-zA-Z][^>]*>' "$FILE")
[ -n "$ON_LINES" ] && report "存在 inline JS 事件属性（行${ON_LINES}）"

if [ "$PROBLEMS" -gt 0 ]; then
  echo "静态检查未通过，共 $PROBLEMS 项问题" >&2
  exit 1
fi
echo "检查通过"
