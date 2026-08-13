---
name: html-visual-reading
description: 把内容做成可视化、卡片式、递进式阅读的单文件 HTML。用于把文章、论文、网页、代码仓库或当前项目落地成一个面向外行读者、由浅入深的解读页面。触发词包括"做成可视化 html""可视化解读""卡片式阅读""把这个项目讲清楚""visual reading"。
---

# HTML 可视化解读

把任意内容——本地文件、整个项目文件夹、一个 URL，或者当前对话已经产出的结论——做成一个单文件、卡片式、由浅入深的可视化 HTML 页面。默认读者是**对这个领域完全外行的聪明人**：不预设任何背景知识，但也不把人当傻子。

流程分五步，按顺序做，第 3 步结束后必须停下来等用户确认。

## 1. 接住输入

先判断拿到的是四种输入里的哪一种：本地文件、本地文件夹、URL，还是当前对话已经产出的内容。四种形态的具体读取方法见 @references/ingest.md。

## 2. 盘素材

**动手画图前先找现成的图。** 原作者、原仓库、原论文往往已经画好了架构图、流程图、示意图——先找，找不到、或者找到的图在正文宽度下读不清，才轮到自己画 SVG。取图优先级、扫描目录清单、远程图校验、收图/弃图标准，见 @references/ingest.md 的"图片"一节。

## 3. 排阅读路径

按 @references/outline.md 给出的模板产出大纲：读者画像、一句话结论、章节序列（每章标注解决什么疑问、用什么组件、配哪张图、拆解哪些名词）、名词表。

**大纲产出后停下来，把大纲交给用户确认。得到明确同意再进入下一步，不要直接往下写 body。**

## 4. 写 body

body.html 的顶层结构固定是三块拼起来：`<header class="page-head container">` + `<nav class="nav">` + `<main class="container">`，直接首尾相接就是整份 body 文件，不含 `<html>`/`<head>`/`<body>` 标签——那些在骨架（`assets/skeleton-head.html` / `skeleton-tail.html`）里，build.sh 拼装时会自动包上。

组件从 @assets/components.md 里挑，直接复制粘贴、按需改文字——样式已经在骨架里定义好，不要另加 `style=` 或 `<style>`。文字怎么写、怎么向外行读者拆解名词，见 @references/writing-style.md。

**禁止写任何 inline JS**（`onclick=` 等事件属性）。所有交互都由骨架自带的脚本经 `data-*` 属性驱动，第 5 步的静态检查会拦截 inline JS 并让构建失败。

## 5. 拼装

body 写好后，用 build.sh 拼成最终产物：

```bash
bash <skill 目录>/scripts/build.sh <body.html> <out.html> "<标题>" "<描述>"
```

`<标题>` 和 `<描述>` 只填进产物 `<head>` 里的 `<title>` 标签和 `meta description`，**不会出现在页面正文里**——页面上可见的 h1 由 body 自己的 `<header>` 写，两者不必一字不差：`<title>` 可以短、带站点感，h1 可以是完整的问题式标题。

`build.sh` 已经内含两道工序，不用另外手动跑：先用 `inline_images.py` 把 body 里引用的图片全部内联成 `data:` URI，再用 `check.sh` 做静态检查。**检查不通过会以退出码 1 结束，并把问题逐条列在输出里**——照着列出的问题改 body，改完重新跑这条命令即可，不用单独调用 `check.sh`。

body 里 `<img src="...">` 写本地相对路径时，**路径相对 body.html 文件所在目录解析**，不是相对当前工作目录、也不是相对被解读项目的根目录——`build.sh` 会把 `<body.html>` 所在目录当作 `--base-dir` 传给 `inline_images.py`。解读一个项目时如果习惯把 body.html 写在别处（比如当前工作目录），图片引用要么写成绝对路径，要么把 body.html 放到和图片同一相对位置，否则内联会因为解析不到文件而失败，产物里留下一张打不开的图（这种情况第 5 步的检查会拦住，见下）。

`check.sh` 只拦资源属性（`src`/`srcset`/`link href`/CSS 里的 `url()`/`@import`），**不拦 `<a href="https://...">` 这类导航链接**——指向原文出处的链接是允许的，也是推荐的写法，正文里该署名、该链回原文时放心加。

## 不做的事

- 不自动开浏览器
- 不自动截图
- 不做深色模式
- 不做多主题
- 不生成配套 README
