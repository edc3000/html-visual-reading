# html-visual-reading

Claude Code skill：把内容（本地文件、项目文件夹、URL，或当前对话的产出）做成一个**单文件、卡片式、由浅入深**的可视化 HTML 页面，面向对该领域完全外行的读者。

Skill 的完整流程写在 [`SKILL.md`](SKILL.md)：接住输入 → 盘素材（先找现成图,再考虑自制）→ 排阅读路径（产出大纲后停下来等确认）→ 写 body（挑组件、按写作规则拆解名词）→ 拼装（`build.sh` 一条命令内联图片 + 静态检查）。

## 目录结构

```
SKILL.md                        skill 入口，五步流程 + frontmatter 触发词
README.md                       本文件
references/
  ingest.md                     四种输入的具体读取方法 + 完整取图规范
  outline.md                    大纲模板与三条硬规则
  writing-style.md              写作规则，每条配正反例
assets/
  skeleton-head.html            页面骨架的 <head>（含全部 CSS token 与样式）
  skeleton-tail.html            页面骨架的收尾脚本（折叠/流程图/导航交互）
  components.md                 可直接复制粘贴的 HTML 组件片段速查
scripts/
  build.sh                      拼装脚本：head + body + tail → 内联图片 → 静态检查
  inline_images.py              把 <img src="..."> 全部转成内联 data: URI
  check.sh                      产出物的静态校验（外链、禁用词、标签配对、重复 id、inline JS）
tests/
  test_build.sh / test_check.sh / test_render.sh / test_inline_images.py
  fixtures/                     测试用的 body 片段与期望产物
```

## 手动跑 build.sh

```bash
bash scripts/build.sh <body.html> <out.html> "<标题>" "<描述>"
```

- `body.html`：只含 `<main class="container">...</main>` 之类的正文片段（不含 `<html>`/`<head>`），组件从 `assets/components.md` 挑。
- `out.html`：产出的单文件 HTML，图片已内联，可以直接双击打开或分享。
- `build.sh` 内部顺序：拼接骨架（`assets/skeleton-head.html` + body + `assets/skeleton-tail.html`）→ 替换标题/描述占位符 → 用 `scripts/inline_images.py` 把图片转成 `data:` URI → 用 `scripts/check.sh` 做静态检查。
- 检查不通过时，`build.sh` 以退出码 `1` 结束，并把每一项问题打印出来；修完 body 里的问题后重新跑同一条命令即可。

也可以单独跑内联脚本或检查脚本：

```bash
python3 scripts/inline_images.py <in.html> <out.html> --base-dir <图片相对路径的基准目录>
bash scripts/check.sh <out.html>
```

## 跑测试

```bash
bash tests/test_build.sh
bash tests/test_check.sh
bash tests/test_render.sh
python3 tests/test_inline_images.py
```

四个测试分别覆盖：`build.sh` 的拼装与占位符替换、`check.sh` 的静态校验规则（含多个对抗性用例）、骨架片段拼出的完整页面渲染是否符合预期、`inline_images.py` 的图片内联逻辑。
