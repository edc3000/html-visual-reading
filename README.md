<div align="center">

# 📖 HTML 可视化解读

**先让读者读懂，再谈可视化。**

把一篇 blog、一篇论文、一份综述，或一整个代码仓库，变成一个能双击打开的单文件中文教学页面。

[![Agent Skill](https://img.shields.io/badge/Agent-Skill-6f42c1?style=flat-square)](./SKILL.md)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-supported-d97757?style=flat-square)](#安装)
[![Output](https://img.shields.io/badge/产物-单个%20HTML-1a1816?style=flat-square)](#三条不随材料变化的硬约束)
[![Requests](https://img.shields.io/badge/外部请求-0-2ea44f?style=flat-square)](#三条不随材料变化的硬约束)
[![Build](https://img.shields.io/badge/构建步骤-无-cc6a3d?style=flat-square)](#环境要求)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](./LICENSE)

[快速开始](#60-秒上手) · [它长什么样](#它长什么样) · [七步流程](#七步流程) · [三条专项路线](#三条专项路线) · [验证](#四层验证) · [FAQ](#faq)

</div>

---

> **English summary** — An agent skill that turns a blog post, a paper, a survey, or an entire code repository into a single self-contained HTML page built for *reading*, not for showing off components. It refuses to touch markup until five written contracts — reader, terminology, dataflow, running example, and the narrative spine — are signed off by the user, then picks sections from the material itself rather than from a template. Output is one file: inlined CSS/JS, base64 images, zero external requests, Chinese prose throughout. A four-layer verification pass (static grep → headless browser at three widths → content → reader comprehension) runs before delivery, and its results are reported honestly, including whatever could not be checked.

---

## 为什么需要它

让模型「把这篇论文做成可视化 HTML」，八成会拿回这么一个页面：

第一屏堆满彩色渐变卡片，主线被切成几十个要点散落各处，关键论证藏在没人点开的折叠区里；图是自己重画的、和原文流程对不上；`rollout` 被贴心地解释了一遍，而论文自造的那个核心术语从头到尾没定义；末尾照例来一节「总结与展望」；页面看起来完全静态——因为某个 JS 字符串里混进了一对中文引号，而没人开过浏览器。

`html-visual-reading` 把这些坑一条条堵住：**先定契约再动笔、section 由材料决定而不是由模板决定、动手画图前先找原作者画好的图、验证必须开浏览器。**

核心原则只有一句——**帮助读者 get 到材料的核心思想**。页面首先要流畅易读，可视化只是让抽象关系更具体，卡片只是让读者在掌握脉络后自然深入细节。

---

## 60 秒上手

### 安装

没有依赖、没有构建，clone 到 skills 目录就行。

<table>
<tr><th>全局启用（所有项目可用）</th><th>只在当前项目启用</th></tr>
<tr valign="top">
<td>

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/edc3000/html-visual-reading \
  ~/.claude/skills/html-visual-reading
```

</td>
<td>

```bash
mkdir -p .claude/skills
git clone https://github.com/edc3000/html-visual-reading \
  .claude/skills/html-visual-reading
```

</td>
</tr>
</table>

更新：`git -C ~/.claude/skills/html-visual-reading pull`

### 调用

Claude Code 会按 `SKILL.md` 里的 description 自动匹配，直接用自然语言说就行：

**读一篇论文 / blog：**

```text
读一下这篇论文，做成可视化 html：https://arxiv.org/abs/<id>
```

**读一份综述：**

```text
把这份 survey 做成可视化解读页面，taxonomy 要能点着看。
```

**读一整个工程项目：**

```text
把 ~/code/<project> 这个项目讲清楚，做成可视化解读页面。
```

**把刚聊完的结论做成页面：**

```text
把刚才聊的做成一个可视化 html，不用重新检索。
```

其他触发词：「可视化解读」「把这个项目讲清楚」「visual reading」「blog to html」。

### 环境要求

| 要求 | 说明 |
|---|---|
| Claude Code | 能读写当前目录 |
| Playwright + Chromium | **强烈建议**。第 6 步的运行时验证靠它自动跑；没装则退化成「让用户自己开 F12 看 Console」，并且必须如实告知没能自动验证 |
| 网络访问 | 输入是 URL / arXiv 论文时需要；本地项目和粘贴文本不需要 |
| Python 3 | 只用来 base64 内联图片、起本地 server（`python3 -m http.server`），标准库足够 |
| macOS 命令 | 图片缩放压缩用 `sips`、取局域网 IP 用 `ipconfig getifaddr en0`。换平台需要替换成等价命令（`magick` / `ip addr`） |
| 第三方依赖 | **零**。产物是单个 HTML，没有构建步骤，没有 `npm install` |

---

## 它长什么样

### 一个 skill 入口，九份 reference，零脚本

```text
SKILL.md                  硬约束、读者画像、七步流程、frontmatter 触发词
references/
├── contracts.md          五份契约 + section 三条硬规则 + 标题自检尺子
├── ingest.md             四种输入的取材方法 + 完整图片规范
├── visual-patterns.md    pattern 库、流程图契约、视觉规范、8 条实现陷阱
├── writing-style.md      中文行文规范，每条配正反例，每条标出「过头的方向」
├── paper.md              单篇论文：元信息、叙事主线、按角色分配篇幅
├── survey.md             综述：taxonomy、递归展开、sub-agent 并行调研
├── project.md            工程项目：模块图、运行流程、设计取舍的素材来源
├── verify.md             四层验证清单，含可直接跑的 Playwright 脚本
└── anti-patterns.md      40 条反面教训，写前扫一遍、验证时再扫一遍
```

**没有构建脚本，也没有固定骨架**——页面按 `visual-patterns.md` 的规范现写，CSS/JS 全部内联，产物是一个可以直接双击打开或分享的 HTML 文件。

### 写 HTML 之前，先交五份契约

```text
1. 读者契约          读者已经知道什么（这些词直接用）、还不知道什么（这些是页面的活）
2. 术语契约          3–8 个骨干术语，逐个定死中文表述、一句话定义、与相邻概念的边界
3. 数据流契约        每个阶段读什么、改什么、出什么；train / val 谁修改候选、谁只打分
4. Running Example   一个贯穿方法部分的真实例子，中间对象实际长什么样
5. 主线契约（最高）  全文压成一个核心问题，每个默认展开的 section 只能承担五种职责之一
```

**契约写完停下来，交给用户确认，得到明确同意再往下写。** 这一步花五分钟，能挡住整页重写。

### section 标题的自检尺子

躲开干巴巴的名词短语之后，别滑到另一个极端：

| 太干（名词短语） | ✅ 好 | 过头（在表演） |
|---|---|---|
| 问题背景 | 这套系统最初要解决什么问题 | 这套系统当年到底踩了什么坑才被逼出来 |
| 架构设计 | 一个请求进来会经过哪些环节 | 一个请求进来之后，都经过了谁 |
| 实验结果 | 比原来的做法好多少 | 它到底赢在哪，赢得漂不漂亮 |
| 失败记录 | 失败的方向怎么处理 | 失败方向为什么要办场葬礼 |

判断标准：**读者会觉得你在陈述，还是觉得你在表演。**

### 验证脚本要么放行，要么把问题指到具体元素上

```bash
python3 verify.py /abs/path/to/page.html
```

<table>
<tr><th align="left">✅ 通过（exit 0）</th><th align="left">❌ 拦截（exit 1）</th></tr>
<tr valign="top">
<td>

```text
OK：无报错、无外部请求、
三档宽度无横向溢出
```

</td>
<td>

```text
[pageerror] SyntaxError: Unexpected identifier
[外部请求] https://cdn.jsdelivr.net/npm/mermaid
[请求失败] https://ar5iv.labs.arxiv.org/x3.png
[横向溢出] 375px 下 scrollWidth=452，
  越界元素：['PRE.code', 'DIV.card-grid']
```

</td>
</tr>
</table>

关键在于它是**在「所有可展开元素都点开」之后**、在 375 / 880 / 1440 三档宽度下测的——这正是页面最容易裂开的状态。

---

## 七步流程

```mermaid
flowchart LR
    A["① 取材<br/>先找现成的图"] --> B["② 定契约<br/>停下来等确认"]
    B --> C["③ 设计阅读路径<br/>三层渐进"]
    C --> D["④ 选可视化手段<br/>一屏一个视觉锚点"]
    D --> E["⑤ 写页面<br/>克制、低饱和"]
    E --> F["⑥ 验证<br/>四层，含浏览器"]
    F --> G["⑦ 交付<br/>如实报告"]
    B -. 契约不对就重来 .-> A
    F -. 有问题回去改 .-> E

    style A fill:#FDF6EC,stroke:#E8E0CC,color:#1A1816
    style B fill:#F4E3D7,stroke:#94441F,stroke-width:2px,color:#1A1816
    style C fill:#FDF6EC,stroke:#E8E0CC,color:#1A1816
    style D fill:#FDF6EC,stroke:#E8E0CC,color:#1A1816
    style E fill:#FDF6EC,stroke:#E8E0CC,color:#1A1816
    style F fill:#F4E3D7,stroke:#94441F,stroke-width:2px,color:#1A1816
    style G fill:#FDF6EC,stroke:#E8E0CC,color:#1A1816
```

**两个加粗的步骤是这套流程的承重墙**，别的都能酌情简化，这两步不行：

- **② 定契约**是唯一一个会**主动停下来等你确认**的检查点。契约错了，页面全得重写；契约对了，后面五步都有据可依。
- **⑥ 验证**是这个 skill 最常见的失败方式所在——静态检查过了不代表 JS 能跑，默认状态正常不代表展开后正常，桌面正常不代表窄屏正常。

阅读路径固定为三层渐进，但 **section 的数量、顺序、命名完全由材料决定，不套固定模板**：

```text
第 1 层：核心结论 + 核心思想          ← 30 秒知道材料在讲什么
第 2 层：连续正文 + 少量关键图解       ← 3–5 分钟读懂脉络
第 3 层：卡片、表格、原话、延伸细节    ← 按需深读
```

> **长文阅读底线**：把所有可展开区域全部折叠后，页面仍必须完整讲清主旨。读者不能被迫点开卡片来拼接主线。

---

## 它解决什么问题

| 😖 常见问题 | ✅ Skill 的处理方式 |
|---|---|
| 拿固定模板套所有材料，不合适的 section 成累赘 | section 数量、顺序、命名由材料决定；「模板优先而非内容优先」是 40 条反面教训的第 1 条 |
| 长文被切成卡片墙，读者到处点才能拼出主线 | 主线契约规定默认展开的 section 只能承担五种职责之一；折叠区全收起后正文必须仍讲得通 |
| 自己重画一张不如原作者准确的架构图 | 动手画之前先找现成图：原文 → 仓库 `figures/` → 文档；取到的图 `curl -sI` 验 HTTP 200 |
| 图配一句「如图所示」就完事 | 每张图必配可展开中文说明，展开态至少 3–5 个分点，逐节点讲清数据流 |
| 中文引号混进 ASCII 引号，整页 JS 静默失效 | 静态检查专门 grep 这一条；中文引用统一改用 `「」` `『』` |
| Lint 过了就交付，打开发现页面是死的 | 运行时验证不可跳过：Playwright 展开所有交互元素，三档宽度扫 Console、外部请求、溢出 |
| accent 色直接当正文色，对比度不达标 | 配色基线给了 `--accent-ink`，并标出 `#CC6A3D` 对底色只有 3.69:1，不到 AA 的 4.5:1 |
| 原文区分的几个概念被压成同一个中文词 | 术语契约逐个定死表述和边界；`context` / `context window` / `context artifacts` 不许都叫「上下文」 |
| 常见术语解释过度，材料自造术语反而不解释 | 读者画像默认「熟悉 LLM 的后训练工程师」；行业通用词一个都不解释，材料自造的必须解释 |
| 代码里没写为什么，就替作者编一个理由 | 找不到 why 宁可写「文档未说明原因」——编出来的理由读者会当真 |
| 末尾照例来一节「总结与展望」 | 硬规则：最后一节不许是总结章，除非它是前文没安放过的**新判断** |
| 引了 CDN 上的 mermaid.js，离线打开就废了 | 单文件零外部请求；mermaid / graphviz 源码**转译**成静态 SVG 或分步流程图，不贴源码 |

---

## 三条专项路线

通用流程之上叠加三条专项，各自有各自最容易翻的车。

| 输入 | 判断依据 | 走哪条 | 叙事主线 | 最容易翻的车 |
|---|---|---|---|---|
| 单篇论文 / blog | 提出了自己的新方法 | [`paper.md`](references/paper.md) | 问题 → 已有方案 → 本文做法 → 有意思的点 → 结论一句话 | **当综述写**：把 20 篇 related work 全铺开，读者反而抓不住本文方法 |
| 综述 / review | 标题含 survey / review / overview，或以分类梳理多篇工作为主 | [`survey.md`](references/survey.md) | 领域全景 → taxonomy → 按分支递归展开 → 跨方法对比 → 开放问题 | **当论文列表写**：不分类就铺开、重点论文只给一句话摘要、用 h3 平铺而非折叠卡片 |
| 本地代码仓库 | 输入是一个文件夹 | [`project.md`](references/project.md) | 要解决什么问题 → 不用它时怎么做 → 核心设计 → 跟着真实例子走一遍 → 关键取舍 → 什么时候别用 | **退化成目录树导览**：一节讲一个目录，每个文件配一句「负责 xxx」；或者把 README 换个说法复述一遍 |

三条路线共有的判断标准：

- **论文**：篇幅按角色分配——引子过渡的不要给终点论文一样的深度
- **综述**：需要深度展开的论文 ≥3 篇时，**必须起 sub-agent 并行调研**，串行逐篇拉 arXiv 会严重拖慢；超过 15 篇先跟用户确认范围
- **项目**：页面价值最高的一节是「关键设计取舍」——素材藏在代码注释的 why、测试用例的名字（`test_does_not_retry_on_4xx`）、防御性代码和 `fix:` 开头的 commit 里

---

## 三条不随材料变化的硬约束

| 约束 | 具体要求 |
|---|---|
| **单文件、零外部请求** | CSS/JS 全部内联；图标用 emoji 或内联 SVG；字体走字体栈不引 CDN；本地图片 base64 内联；远程图片校验过 HTTP 200 才直引 |
| **中文** | 正文 / 标题 / 导航 / 按钮 / 提示一律中文。只有专有名词、代码命令、需要原味的金句保留英文（金句要配中文译文） |
| **源链接显式引用** | 页头或核心结论附近一个「阅读原文 ↗」，页脚再出现一次并附作者 / 站点名。项目场景同理，链回仓库 |

另外还有一条禁用词规则：**页面里不许出现「TL;DR」这个字面词**（连同「太长不看」「综上所述」「笔者认为」「众所周知」「不言而喻」）。三层渐进披露的结构照用，但第一层叫「核心结论」。

### 风格底线：克制、低饱和、信息优先

不做装饰性炫技，不靠颜色堆砌存在感；**强调用字重 / 字号 / 留白，不用颜色**。一套验过对比度的基线配色可以直接用：

```css
--bg:          #FAF7F0;  /* 页面底色，暖白 */
--surface:     #FFFFFF;  /* 卡片 */
--line:        #E8E0CC;  /* 分割线、边框 */
--text:        #1A1816;  /* 正文，对 --bg 16.8:1 */
--muted:       #6B6660;  /* 次要文字，对 --bg 5.4:1 */
--accent:      #CC6A3D;  /* 暖赭，只用于色块、边框、图标 */
--accent-soft: #F4E3D7;  /* accent 的浅色底 */
--accent-ink:  #94441F;  /* accent 的文字版，对 --bg 6.8:1 */
```

> **最容易犯也最容易被忽略的一个错**：`--accent` 不能直接用于正文级文字。`#CC6A3D` 对 `#FAF7F0` 只有 3.69:1，不到 WCAG AA 要求的 4.5:1。链接、按钮文案、可展开触发器一律用 `--accent-ink`。

明确禁止：彩色渐变背景、霓虹/荧光色、发光效果、彩虹色文字、玻璃拟态堆叠、旋转/弹跳/无限 loop 动画、装饰性粒子。

**自检**：把页面截图转成灰度，如果信息层级依然清晰，说明颜色用对了。

---

## 四层验证

**跳过验证是这个 skill 最常见的失败方式。** 四层逐个过，清单和可直接运行的脚本在 [`verify.md`](references/verify.md)。

| 层 | 查什么 | 怎么查 |
|:--:|---|---|
| **1. 静态** | 引号嵌套、外部请求、禁用词、DOM id 重复、`<script>` 开闭配对、`getElementById` 目标是否存在 | 六项 `rg` 检查，每条命中都要处理 |
| **2. 运行时** | Console 报错、外部请求、加载失败的资源、展开态下的横向溢出 | Playwright 脚本，三档宽度 × 点开所有可交互元素。**绝不能跳过** |
| **3. 内容** | 核心数字与原文对齐、外链指向真正的原文、关闭所有卡片后主线是否还完整、最大的那张图是否忠于原文流程 | 人读，逐条对 |
| **4. 读者理解** | 假设读者没读过原材料，他能否答出「优化的对象是什么」「一轮流程读什么改什么出什么」「一次运行留下什么给下次」 | 答不出就回到契约，检查是哪份没落实 |

脚本替代不了人眼的部分——视觉层级、配色是否太跳、留白够不够、小字有没有糊——跑完仍要 `open` 自己看一眼。

> **本机没有 Playwright 时**，第 2 层退化成「让用户开浏览器按 F12 看 Console」，并且**必须明确告诉用户你没能自动验证**。谎报验证结果是反面教训的最后一条。

---

## 40 条反面教训

每条都是真踩过的，按主题分成五组：结构与叙事 14 条、术语与读者 8 条、图 8 条、代码与交互 6 条、验证 4 条。写之前扫一遍，验证时再扫一遍，全文在 [`anti-patterns.md`](references/anti-patterns.md)。

踩得最多的五条：

1. **模板优先而非内容优先** —— 拿着固定模板塞内容
2. **中文双引号混 ASCII 双引号** —— JS 直接 parse 失败，页面看起来是静态的
3. **只做静态检查不开浏览器** —— Lint 过不代表 JS 能跑
4. **把长文切成卡片墙** —— 卡片承载补充细节，不能取代连续正文
5. **没有读者画像就开始写** —— 常见术语解释过度、材料专属术语解释不足，同时发生

`writing-style.md` 还有一层元规则：**每条规则都有过头的方向**。「标题写成问题」过头会变成抖机灵，「解释术语」过头会连 `rollout` 都立一张卡，「并列改列表」过头会满页列表没有一段连贯叙述。**原来的毛病只是平庸，过头的毛病是做作。**

---

## FAQ

<details>
<summary><b>为什么第 2 步一定要停下来等我确认？</b></summary>

因为契约错了，整页都得重写。读者画像定错，会同时发生「常见术语解释过度」和「自造术语不解释」；主线契约定错，section 会一节节长出来又一节节删掉。这一步花五分钟，挡住的是一次整页返工。

契约不一定原样出现在页面上，但它必须指导全文——你可以只扫一眼确认「读者画像对、术语表述对、主线问题问对了」，就能放行。

</details>

<details>
<summary><b>它会不会把我的文章切成一堆卡片？</b></summary>

不会，这是被明确禁止的退化模式（反面教训第 3 条）。规则是：**连续正文是骨架，图解和卡片是辅助**；把页面里所有折叠区全部收起后，正文从头读到尾必须仍然讲得通、论证链条不断。

真正支撑结论的关键论证不能只存在于点开之后——折叠卡片是加餐，不是承重墙。这条规则的优先级高于其它所有规则。

</details>

<details>
<summary><b>没装 Playwright 还能用吗？</b></summary>

能，但验证质量会下降，而且 skill 会**明确告诉你哪一层没跑成**，不会假装跑过。第 1、3、4 层不依赖浏览器，照常执行；第 2 层退化成让你自己开 F12 看 Console。

想要完整体验就装上：`pip install playwright && playwright install chromium`。

</details>

<details>
<summary><b>综述引了 30 篇论文，会一篇篇串行读吗？</b></summary>

不会。需要深度展开的论文 ≥3 篇时，规则是**必须起 sub-agent 并行调研**——每篇一个 `general-purpose` agent 后台跑，负责拉 arXiv HTML、定位 method section、提取并 `curl -sI` 验证图片 URL、整理示例，全部返回后再统一构建 HTML。

同时有一条硬止损：如果发现自己在为一篇论文写少于 3 段方法讲解、且没有配图，说明素材不够，要停下来先调研，而不是凑两行糊过去。

</details>

<details>
<summary><b>为什么不用 mermaid.js、Tailwind CDN 这些现成轮子？</b></summary>

因为产物要**单文件、零外部请求**——发给别人、断网打开、几年后再点开都得能用。走 CDN 违反这一条，把整个库内嵌进来体积又不可接受。

所以 README/文档里的 mermaid、graphviz 源码要**转译**成静态 SVG 或分步流程图（源码里的节点和连线是现成结构，照着译比自己凭空设计更忠于原意），并在契约里如实标注「转译自 README 的 mermaid」。**不要把源码原样贴成代码块**——那等于把渲染的活丢给读者脑内完成。

</details>

<details>
<summary><b>为什么页面里不许出现「TL;DR」？</b></summary>

三层渐进披露的结构是照用的，被禁的只是这个字面词——它是英文缩写，中文读者未必认识，而且「核心结论」四个字更准确地说明了那一块是什么。同一批被禁的还有「太长不看」「综上所述」「笔者认为」「众所周知」「不言而喻」，后面几个都是「我说了算」式的空洞收尾，对理解没有帮助。

静态检查会逐字 grep 这几个词。

</details>

<details>
<summary><b>读者画像能改吗？我的材料不是给工程师看的。</b></summary>

能，以你的要求为准。默认画像是「熟悉 LLM 的后训练工程师」——`rollout`、`SFT`、`harness`、`agent loop` 这类词直接用不解释。材料面向明显不同的读者群时，在第 2 步的读者契约里改掉即可。

注意读者画像**是读者契约的输入，不是替代品**：每次仍要写清这一次的读者已经知道什么、还不知道什么。

</details>

<details>
<summary><b>交付的时候它会顺手给我写个 README 吗？</b></summary>

不会，第 7 步明确规定不主动写 README。交付只做三件事：如实报告验证结果（跑过哪几层、修了什么、哪条没跑成）、列 2–3 个可迭代方向、起一个本地 server 把访问地址给你（给局域网 IP，不给 localhost，方便手机上打开看窄屏效果）。

</details>

---

## 深入阅读

| 文档 | 内容 |
|---|---|
| [`SKILL.md`](./SKILL.md) | Skill 主说明：硬约束、读者画像、七步流程、触发词 |
| [`references/contracts.md`](references/contracts.md) | 五份契约的模板与判据、section 三条硬规则、标题自检尺子 |
| [`references/ingest.md`](references/ingest.md) | 四种输入的取材方法、arXiv 取图与验证、base64 内联、收图标准 |
| [`references/visual-patterns.md`](references/visual-patterns.md) | 13 种 pattern、流程图契约、配色与排版基线、8 条实现陷阱 |
| [`references/writing-style.md`](references/writing-style.md) | 中文行文规范：讲透为什么、解释密度、翻译腔、数字参照系 |
| [`references/paper.md`](references/paper.md) | 单篇论文：元信息标注、Related Work 可视化、按角色分配篇幅 |
| [`references/survey.md`](references/survey.md) | 综述：taxonomy 骨架、问题解耦、递归展开、sub-agent 并行调研 |
| [`references/project.md`](references/project.md) | 工程项目：模块图与运行流程图、真实例子、设计取舍的素材来源 |
| [`references/verify.md`](references/verify.md) | 四层验证清单 + 可直接运行的 Playwright 脚本 |
| [`references/anti-patterns.md`](references/anti-patterns.md) | 40 条反面教训 |

---

## 参与贡献

欢迎 issue 和 PR。改动 skill 内容时请注意：

1. **不要把某一次改稿的结构写成通用结构。** 每份材料的阅读路径不同，固化模板正是这个 skill 要反对的东西（反面教训第 2 条）。
2. **新增规则必须配正反例。** `writing-style.md` 的体例是「规则 + 正例 + 反例」，只写一句规则读者判断不了边界在哪。
3. **加规则之前先想它「过头的方向」是什么。** 每条规则都能被用力过猛地执行，把那一栏也写出来。
4. **踩到新坑就补进 `anti-patterns.md`**，同时在对应 reference 里给出解法——反面教训负责让人认出坑，reference 负责给出怎么绕过去。
5. **不要引入构建步骤或第三方运行时依赖。** 产物必须保持「双击就能打开的单个 HTML」。

---

## 致谢

这个 skill 以 [@syt-nju](https://github.com/syt-nju) 的 [`blog-to-html`](https://github.com/syt-nju/my_cursor/blob/main/.agent/commands/blog-to-html.md) 为基底重写而来。

「先让读者读懂、可视化只是辅助」这条主张，以及渐进式披露的整体思路，都来自那份原始命令。本仓库在它之上补了五份契约的确认环节、工程项目专项、四层验证清单和 40 条反面教训。

感谢原作者把这套方法公开出来。

---

## 许可

[MIT](./LICENSE)

> 原始的 `blog-to-html` 所在仓库 `syt-nju/my_cursor` 未附带 license，本仓库的 MIT 只覆盖本仓库自身的内容。如果你要在商业场景里分发本仓库，建议先与原作者确认。

---

<div align="center">

这套规则来自反复重写页面之后沉淀的判断——每一条反面教训都真的踩过一次。

<br/>

如果它帮你省下了一次整页返工，点个 ⭐ 吧。

</div>
