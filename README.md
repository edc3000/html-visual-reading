# html-visual-reading

Claude Code skill：把一篇 blog / paper / survey / 长文，或一整个工程项目，转成**单文件、自包含、适合阅读**的教学可视化 HTML。

核心原则是**帮助读者 get 到材料的核心思想**——页面首先要流畅易读，可视化只是让抽象关系更具体，卡片只是让读者在掌握脉络后自然深入细节。默认读者是熟悉 LLM 的后训练工程师。

完整流程写在 [`SKILL.md`](SKILL.md)：取材 → 定契约（**停下来等确认**）→ 设计阅读路径 → 选可视化手段 → 写页面 → 验证 → 交付。

## 目录结构

```
SKILL.md                  skill 入口：硬约束、读者画像、七步流程、frontmatter 触发词
README.md                 本文件
references/
  contracts.md            五份契约（读者/术语/数据流/running example/主线）+ section 硬规则
  ingest.md               四种输入的取材方法 + 完整图片规范（取图、arXiv、内联、说明格式）
  visual-patterns.md      pattern 库、流程图契约、视觉与交互规范、实现陷阱
  writing-style.md        中文行文规范，每条配正反例
  paper.md                单篇论文专项：元信息标注、叙事主线、篇幅分配
  survey.md               综述专项：taxonomy、递归展开、sub-agent 并行调研
  project.md              工程项目专项：模块图、运行流程、设计取舍的素材来源
  verify.md               四层验证清单，含可直接运行的 Playwright 检查脚本
  anti-patterns.md        40 条反面教训，写前扫一遍、验证时再扫一遍
```

没有构建脚本，也没有固定骨架——页面按 `visual-patterns.md` 的规范现写，CSS/JS 全部内联，产物是一个可以直接双击打开或分享的 HTML 文件。

## 三条不随材料变化的硬约束

- **单文件、零外部请求**：CSS/JS 内联，图标用 emoji 或内联 SVG，字体走字体栈不引 CDN，本地图片 base64 内联
- **中文**：正文/导航/按钮一律中文，只有专有名词、代码、需要原味的金句保留英文
- **源链接显式引用**：页头和页脚各出现一次，链回原文或原仓库

## 验证

产物写完后跑 [`references/verify.md`](references/verify.md) 里的四层检查。运行时那层可以自动跑——本机装了 Playwright + Chromium，脚本会在 375 / 880 / 1440 三档宽度下展开所有可交互元素，一次覆盖 Console 报错、外部请求、加载失败的资源和横向溢出。
