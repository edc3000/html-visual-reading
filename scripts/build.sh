#!/bin/bash
# 把 body 片段拼进骨架，产出单文件 HTML。
set -euo pipefail

if [ $# -lt 4 ]; then
  echo "用法: build.sh <body.html> <out.html> \"<标题>\" \"<描述>\"" >&2
  exit 1
fi

BODY="$1"; OUT="$2"; TITLE="$3"; DESC="$4"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HEAD="$ROOT/assets/skeleton-head.html"
TAIL="$ROOT/assets/skeleton-tail.html"

[ -s "$BODY" ] || { echo "错误: body 文件不存在或为空: $BODY" >&2; exit 1; }
[ -f "$HEAD" ] || { echo "错误: 缺少 $HEAD" >&2; exit 1; }
[ -f "$TAIL" ] || { echo "错误: 缺少 $TAIL" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat "$HEAD" "$BODY" "$TAIL" > "$TMP/merged.html"

# 用 python 做占位替换，避免 sed 对 & / 斜杠等字符的转义陷阱
python3 - "$TMP/merged.html" "$TMP/titled.html" "$TITLE" "$DESC" <<'PY'
import sys
src, dst, title, desc = sys.argv[1:5]
with open(src, encoding='utf-8') as f:
    html = f.read()
html = html.replace('__TITLE__', title).replace('__DESCRIPTION__', desc)
with open(dst, 'w', encoding='utf-8') as f:
    f.write(html)
PY

cp "$TMP/titled.html" "$OUT"
echo "已生成: $OUT ($(wc -c < "$OUT" | tr -d ' ') 字节)"
