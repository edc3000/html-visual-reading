# 组件速查

写 body 片段时从这里挑组件，直接复制粘贴、按需改文字。**这份文档只含 HTML 片段和使用场景，不含任何 CSS** —— 样式已经在骨架里定义好了，不要在片段里加 `style=` 或另写 `<style>`。

使用须知（写之前先看一遍）：

1. 页面结构固定为 `<header class="page-head container">` → `<nav class="nav">` → `<main class="container">`，main 内部每章是一个 `<section class="section" id="...">`。
2. **禁止写任何 inline JS**（`onclick=` 等）。交互全部由骨架脚本经 `data-*` 属性驱动。`check.sh` 会拦截 inline JS 事件属性，构建会直接失败。
3. **可点击元素必须带 `tabindex="0" role="button" aria-expanded="false"`** —— 骨架脚本靠这些属性支持键盘操作和状态播报，漏了就等于键盘用户完全用不了折叠功能。
4. `.grid` 内只放同类卡片。混入其它元素会让 `.concept:nth-child(2n)` 的橙绿交替错位。
5. 按需取用，不要每个组件都用上。一屏至多一个视觉锚点（大图或流程图）。
6. 并列关系用卡片，链式关系用流程图，量化结论用数字条。
7. 所有可折叠区域的折叠态必须带一句话摘要，不能只挂标题。

---

## 1. 页头

什么时候用：每份文档必有且只有一个，是 `<body>` 的第一个元素。

```html
<header class="page-head container">
  <div class="tags"><span class="tag">示例</span><span class="tag neutral">测试</span></div>
  <h1>这份内容到底在讲什么</h1>
  <p class="page-sub">一句话副标题，用来交代范围和读者能得到什么。</p>
  <div class="page-meta"><span>约 8 分钟</span><span>2026-08-12</span></div>
</header>
```

`.tags` 和 `.page-meta` 都可以省略，`h1` 和 `.page-sub` 必须留。

## 2. 核心结论块

什么时候用：读者最该带走的一句话结论。作为 `.page-head` 内的最后一个元素、`</header>` 之前插入，一份文档至多一个。

```html
  <div class="keypoint">
    <div class="keypoint-label">一句话结论</div>
    <p>这里放读者最该带走的那一句，<b>关键处加粗</b>。</p>
  </div>
```

## 3. 章节导航

什么时候用：紧跟在 `</header>` 之后、`<main>` 之前，锚点数量和文字要跟每个 section 的 `id`/`h2` 对上。

```html
<nav class="nav">
  <div class="nav-inner">
    <a href="#s1">这是什么</a>
    <a href="#s2">为什么重要</a>
  </div>
</nav>
```

## 4. 章节头

什么时候用：`<main class="container">` 内每个 `<section class="section" id="...">` 开头都要有，交代这一章要讲什么。

```html
  <section class="section" id="s1">
    <div class="section-num">01</div>
    <h2>这是什么</h2>
    <p class="section-lead">导语，交代这一章要解决读者的哪个疑问。</p>
  </section>
```

`.section-lead` 可省，`.section-num` 和 `h2` 必留；`section-num` 按章节顺序编号（`01`、`02`……）。组件 5–14 的内容插入到 `<p class="section-lead">` 之后、`</section>` 之前——也就是先删掉这里的 `</section>`，接上若干个组件，最后再补回 `</section>`。

## 5. 概念卡网格

什么时候用：一次性介绍几个并列的概念或术语。不要用来堆放不同类的信息（会破坏下面第 4 条规则说的交替配色）。

约束：每张卡固定四段——`h3` 术语中文名、`.term` 英文原名、`p` 一句话定义、`.analogy` 日常类比。**类比不可省**，这是给外行读者的桥。

```html
    <div class="grid c2">
      <div class="concept">
        <h3>粒子滤波</h3>
        <div class="term">Particle Filter</div>
        <p>同时保留很多种可能的猜测，再根据新证据淘汰不合理的那些。</p>
        <div class="analogy">像找钥匙时先列出十个可能放的地方，每想起一个细节就划掉几个。</div>
      </div>
      <div class="concept">
        <h3>中位数聚合</h3>
        <div class="term">Median Aggregation</div>
        <p>把多次测量取中间那个值，而不是取平均。</p>
        <div class="analogy">评委打分去掉最高最低分，防一个人乱打就带偏结果。</div>
      </div>
    </div>
```

两张卡用 `.grid.c2`，三张卡用 `.grid.c3`；卡片数量要和列数对上，别用 `c3` 装两张卡。

## 6. 数字条

什么时候用：量化结论——用几个关键数字给读者一个数量级感。

约束：`.metrics` 是固定 4 列布局，指标数量最好凑够 4 个；少于 4 个桌面端右侧会留白（880px 以下断点自动转 2 列，不受影响）。

```html
    <div class="metrics">
      <div class="metric">
        <div class="metric-value">773</div>
        <div class="metric-label">训练井数量</div>
        <div class="metric-note">相当于一个中型油田的全部记录</div>
      </div>
      <div class="metric">
        <div class="metric-value">5.09M</div>
        <div class="metric-label">训练总行数</div>
        <div class="metric-note">逐行读完要不吃不喝三个月</div>
      </div>
      <div class="metric">
        <div class="metric-value">3</div>
        <div class="metric-label">公开测试井</div>
        <div class="metric-note">答题时只有这三口可参考</div>
      </div>
      <div class="metric">
        <div class="metric-value">0.5</div>
        <div class="metric-label">分箱精度（英尺）</div>
        <div class="metric-note">约一个成年人的小臂长度</div>
      </div>
    </div>
```

`.metric-note` 用一句类比帮读者理解数字的量级，可省但建议留。

## 7. 双栏对比

什么时候用：讲清"适合/不适合""优点/缺点"这类二元对照。

```html
    <div class="panels">
      <div class="panel good">
        <div class="panel-title"><span class="dot"></span>适合这么做</div>
        <ul><li>信息来源互相独立</li><li>单一来源容易失效</li></ul>
      </div>
      <div class="panel bad">
        <div class="panel-title"><span class="dot"></span>不适合这么做</div>
        <ul><li>数据量小到不够分</li><li>各来源其实同源</li></ul>
      </div>
    </div>
```

## 8. 提示条

什么时候用：不打断阅读流的旁注——补充说明用 `.note`，需要警惕的注意事项用 `.note.warn`。

```html
    <div class="note"><b>补充：</b>这是一条普通提示。</div>
    <div class="note warn"><b>注意：</b>这是一条需要警惕的提示。</div>
```

## 9. 代码块

什么时候用：贴一段关键代码，帮读者理解实现细节。

```html
    <div class="code-cap">关键代码 · 把一口井压成参考曲线</div>
    <pre><code>grouped = df.groupby(bin_id)["gr"].median()</code></pre>
```

## 10. 公式块

什么时候用：给出精确的定义式或计算规则，多行用 `<br>` 分隔。

```html
    <div class="formula"><b>分箱：</b>bin(x) = round(x / 0.5) × 0.5<br><b>聚合：</b>median</div>
```

## 11. 可展开卡片

什么时候用：默认收起、按需展开的补充细节——比如"为什么要这么做"的解释。折叠态必须带一句话摘要，不能只挂标题。

```html
    <div class="expand">
      <div class="expand-head" tabindex="0" role="button" aria-expanded="false">
        <div class="expand-num">01</div>
        <div>
          <div class="expand-title">为什么要先降噪</div>
          <div class="expand-summary">不降噪的话，一个异常值就能把后面的对齐整体带偏。</div>
        </div>
        <div class="expand-caret">▸</div>
      </div>
      <div class="expand-body"><div class="expand-body-inner">
        <p>展开后的细节说明。折叠起来时上面那句摘要必须已经说清楚要点。</p>
      </div></div>
    </div>
```

`tabindex="0" role="button" aria-expanded="false"` 必须原样写在 `.expand-head` 上——骨架脚本靠这几个属性做键盘操作和状态播报。

## 12. 分步流程图

什么时候用：链式、有先后顺序的流程。一屏至多一个。

约束：节点 3–6 个；每个 `.flow-node` 必须有 `data-step` 和 `data-caption`；`.flow-caption` 必须有 `data-idle`，且初始文本内容要和 `data-idle` 一致；`.flow-progress` 初始文本写 `0 / <节点数>`；按钮用 `data-flow-action="next|prev|reset"`。

```html
    <div class="flow" data-cur="0">
      <div class="flow-controls">
        <button class="btn btn-primary" data-flow-action="next">下一步</button>
        <button class="btn btn-ghost" data-flow-action="prev">上一步</button>
        <button class="btn btn-ghost" data-flow-action="reset">重置</button>
        <span class="flow-progress">0 / 3</span>
      </div>
      <div class="flow-stage">
        <div class="flow-node" data-step data-caption="第一步：读入原始记录，先不做任何加工。">
          <div class="flow-node-title">读入数据</div>
          <div class="flow-node-desc">把原始记录逐行加载进来</div>
        </div>
        <div class="flow-node" data-step data-caption="第二步：把噪声压掉，只保留稳定的形状。">
          <div class="flow-node-title">降噪</div>
          <div class="flow-node-desc">去掉尖峰和异常值</div>
        </div>
        <div class="flow-node" data-step data-caption="第三步：和参考曲线对齐，给出最终答案。">
          <div class="flow-node-title">对齐输出</div>
          <div class="flow-node-desc">与参考曲线比对后输出</div>
        </div>
      </div>
      <div class="flow-caption" data-idle="点“下一步”开始，看这条流水线怎么一步步走完。">
        点“下一步”开始，看这条流水线怎么一步步走完。
      </div>
    </div>
```

`.flow` 上的 `data-cur="0"` 要写，节点数变了记得同步改 `.flow-progress` 里的分母。

## 13. 图片与折叠说明

什么时候用：一张示意图配文字导览。一屏至多一个视觉锚点。

约束：`.fig-cap` 一句话说清整张图在讲什么；`.fig-detail-inner` 里至少 3 条分点，逐个讲清模块/箭头/配色的含义；宽流程图给 `figure` 加 `.fig-scroll` 允许横向滚动，不要压扁。

```html
    <figure>
      <img src="diagram.png" alt="示意图">
      <div class="fig-cap">这张图讲的是三个阶段之间的数据流向。</div>
      <span class="fig-toggle" tabindex="0" role="button" aria-expanded="false">展开说明 ▸</span>
      <div class="fig-detail"><div class="fig-detail-inner">
        <ul>
          <li><b>左侧方块</b>：原始输入，此时还没有任何加工。</li>
          <li><b>中间箭头</b>：代表数据流向，不代表时间长短。</li>
          <li><b>右侧方块</b>：最终输出，已经过对齐。</li>
        </ul>
      </div></div>
    </figure>
```

`img` 的 `src` 用本地路径或 `data:` URI，构建脚本会自动内联；禁止写 `http(s)` 外链，`check.sh` 会拦截。图偏宽（比如流程截图）时用 `<figure class="fig-scroll">`。

## 14. 结尾清单

什么时候用：一章结束时收束成几条可带走的结论，放在 section 末尾。

```html
    <div class="takeaway">
      <ul><li>第一条可带走的结论</li><li>第二条可带走的结论</li></ul>
    </div>
```
