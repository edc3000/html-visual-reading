# 验证（必做，这步省不掉）

**跳过验证是这个 skill 最常见的失败方式。** 静态检查过了不代表 JS 能跑；默认状态正常不代表展开后正常；桌面正常不代表窄屏正常。四层逐个过。

---

## 第 1 层：静态检查

写完立刻跑。每条命中都要处理。

### 引号嵌套（最高频，会让整页 JS 失效）

```bash
rg '(title|body|hint|example|label|text|caption|summary):\s*"[^"]*"[^"]*"' <file>
rg "(title|body|hint|example|label|text|caption|summary):\s*'[^']*'[^']*'" <file>
```

命中即说明 JS 字符串里有嵌套同类型引号，会让整个 `<script>` parse 失败。
**解法**：中文引用改用 `「」` `『』`，或切换引号类型 / 改模板字符串。

### 外部请求（违反单文件自包含）

```bash
rg -n -i '(src|href)\s*=\s*["'"'"']https?://|url\(\s*["'"'"']?https?://|@import\s+["'"'"']?https?://' <file>
```

命中的分两种：

- **资源引用**（`<script src>`、`<link href>`、`<img src>`、CSS `url()`、`@import`）—— 必须消除。CSS/JS 内联，本地图片 base64
- **导航链接**（`<a href="https://...">`）—— 允许，而且源链接是硬约束要求的。校验过的远程图片 URL 同样允许

### 禁用词

```bash
rg -n -i 'TL;?DR|太长不看|综上所述|笔者认为|众所周知|不言而喻' <file>
```

### 过程词泄漏（AI 味最重的一类）

```bash
rg -n '契约|读者画像|承重墙|渐进披露|视觉锚点|折叠态|主线' <file>
```

这些是本 skill 的工作词汇，不是页面用词。每条命中回原材料查一次：材料本身在用这个词就保留，材料没用就改写成材料自己的说法（真实案例：把项目的 SKILL.md 标成「Skill 契约与参考规则」，原材料从没这么叫过）。

### DOM id 唯一性

```bash
rg -o 'id="[^"]+"' <file> | sort | uniq -d
```

有输出就是重复 id。重复不报错，但 `getElementById` 只会拿到第一个，表现为「有的卡片点了没反应」。

### 结构完整性

```bash
F=<file>
echo "script 开=$(rg -o '<script' $F | wc -l) 闭=$(rg -o '</script>' $F | wc -l)"   # 必须相等
for t in '<!DOCTYPE' '<html' '<main'; do
  echo "$t = $(rg -o -i -- "$t" $F | wc -l)"                                        # 各自只能是 1
done
```

（用 `-o` 数出现次数，`rg -c` 数的是匹配**行数**——同一行写两个 `<script>` 会被算成 1 个，漏掉。）

`<!DOCTYPE>` / `<html>` / `<main>` / 主脚本出现两次，说明重复写入拼接了两份完整页面——这在多次 Edit 之后很常见。

### getElementById 的目标都存在

把 `rg -o "getElementById\(['\"][^'\"]+" <file>` 的结果和上面的 id 列表对一遍。

### 最后

ReadLints 过一遍。

---

## 第 2 层：运行时检查（绝不能跳过）

本机装了 Playwright + Chromium，这层可以自动跑。把下面这段存成临时脚本执行，参数是 HTML 的绝对路径：

```python
import sys
from playwright.sync_api import sync_playwright

path = sys.argv[1]
problems = []
SEL = "[onclick], [data-toggle], .fig-toggle, summary, [role=button], [aria-expanded]"

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.on("console", lambda m: problems.append(f"[console] {m.text}") if m.type == "error" else None)
    page.on("pageerror", lambda e: problems.append(f"[pageerror] {e}"))
    page.on("requestfailed", lambda r: problems.append(f"[请求失败] {r.url}"))
    page.on("request", lambda r: problems.append(f"[外部请求] {r.url}")
            if r.url.startswith(("http://", "https://")) else None)

    for w in (375, 880, 1440):
        page.set_viewport_size({"width": w, "height": 900})
        page.goto("file://" + path)
        page.wait_for_timeout(300)
        for el in page.query_selector_all(SEL):      # 展开所有可交互元素
            try:
                el.click(timeout=800)
            except Exception:
                pass
        page.wait_for_timeout(400)
        sw = page.evaluate("document.documentElement.scrollWidth")
        if sw > w + 1:
            bad = page.evaluate(
                "(w)=>[...document.querySelectorAll('*')]"
                ".filter(e=>e.getBoundingClientRect().right>w+1)"
                ".slice(0,5).map(e=>e.tagName+'.'+(e.className||''))", w)
            problems.append(f"[横向溢出] {w}px 下 scrollWidth={sw}，越界元素：{bad}")
    browser.close()

print("\n".join(dict.fromkeys(problems)) if problems else "OK：无报错、无外部请求、三档宽度无横向溢出")
sys.exit(1 if problems else 0)
```

它一次覆盖四件事：**Console 报错、外部请求、加载失败的资源（含打不开的图）、展开态下的横向溢出**，并且是在「所有可展开元素都点开」之后测的——这正是最容易裂开的状态。

**这个脚本替代不了的，仍然要人看**：

- 视觉层级对不对、配色是不是太跳、留白够不够
- 步进动画每一步的文案是不是对得上状态
- 图有没有被压扁、小字有没有糊

所以脚本跑完还要 `open <file>` 自己看一眼，并把结果如实报告给用户。**本机没有 Playwright 时，这一层退化成：让用户开浏览器按 F12 看 Console，并明确告诉用户你没能自动验证。不要假装跑过。**

**改完页面重新打开时加 cache-busting 参数**（`?v=<timestamp>`），避免把浏览器缓存误认为当前版本。

---

## 第 3 层：内容检查

- **核心数字与原文对齐**（别幻觉）
- **所有外链 URL 正确**，源链接指向真正的原文
- 页头的核心结论真的能让目标读者 30 秒抓住核心思想
- **把全部标题抽出来连读**（`rg -o '<h[123][^>]*>[^<]*' <file>`）：应该像目录，不像语录合集。同一句式（「A 不等于 B」「先 A 再 B」「把 A 变成 B」）出现两次以上，或标题里有材料中不存在的抽象名词（如「事实容器」「过程纪律」），逐个改成带材料专属名词的平实短语
- section 顺序读起来顺滑，能自然从主旨走到细节
- **为每个默认展开的 section 写一句「它如何回答核心问题」**；写不出来就删除或降为折叠细节
- **关闭所有卡片从头读一遍**，确认仍能复述「问题 → 方法 → 证据 → 边界」
- 检查卡片之间是否需要读者自行拼接逻辑；如果需要，说明关键过渡缺失在主线正文中
- **最大的一张图是否准确表达原文的真实流程**；如果图里节点顺序错了，宁可删图
- 所有交互是否帮助逐步阅读；没有学习价值或打断阅读的交互删掉

---

## 第 4 层：目标读者理解检查

假设读者是没读过原材料的目标读者（默认：LLM 后训练工程师），检查他能否回答：

- 这份材料究竟优化、训练、搜索或自动化了什么对象？
- 核心术语分别指什么，彼此是什么包含关系？
- 一轮流程读取什么、修改什么、输出什么？
- train / validation / test 各自做什么，信息是否跨 split 流动？（论文场景）
- 一次运行读了哪些文件、写了哪些状态、留下什么给下次？（项目场景）
- 被比较和保留的是单个对象，还是一组相互关联的对象？
- 放到一个具体任务中，中间文件、状态和最终输出实际长什么样？

**如果读者只能复述术语、不能回答这些问题，说明页面仍未讲清楚。** 回到 @references/contracts.md 检查是哪份契约没落实。
