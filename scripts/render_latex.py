#!/usr/bin/env python3
"""Render a trusted LaTeX math fragment to a self-contained inline SVG."""

from __future__ import annotations

import argparse
import html
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


BLOCKED_COMMANDS = re.compile(
    r"\\(?:input|include|openin|openout|read|write|write18|immediate|"
    r"documentclass|usepackage|catcode|csname|newcommand|renewcommand|def|special)\b",
    re.IGNORECASE,
)


def fail(message: str) -> None:
    print(f"render_latex.py: {message}", file=sys.stderr)
    raise SystemExit(1)


def run(command: list[str], cwd: Path, env: dict[str, str]) -> None:
    completed = subprocess.run(
        command,
        cwd=cwd,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        fail(f"command failed: {' '.join(command)}\n{completed.stdout}")


def svg_fragment(svg: str, tex: str, label: str) -> str:
    start = svg.find("<svg")
    if start < 0:
        fail("dvisvgm output does not contain an SVG root")

    svg = svg[start:]
    svg = re.sub(r"\swidth=(['\"])[^'\"]+\1", "", svg, count=1)
    svg = re.sub(r"\sheight=(['\"])[^'\"]+\1", "", svg, count=1)
    attributes = (
        f' role="img" aria-label="{html.escape(label, quote=True)}"'
        f' data-tex="{html.escape(tex, quote=True)}" focusable="false"'
    )
    return svg.replace("<svg", f"<svg{attributes}", 1)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Render a trusted LaTeX math fragment to path-based inline SVG."
    )
    parser.add_argument("--tex", required=True, help="LaTeX math fragment without $ delimiters")
    parser.add_argument("--output", required=True, type=Path, help="Output SVG fragment")
    parser.add_argument("--label", help="Accessible plain-language label; defaults to the TeX source")
    parser.add_argument("--border", type=float, default=2.0, help="Crop border in pt (default: 2)")
    args = parser.parse_args()

    if BLOCKED_COMMANDS.search(args.tex):
        fail("the fragment contains a blocked non-math TeX command")

    latex = shutil.which("latex")
    dvisvgm = shutil.which("dvisvgm")
    if not latex or not dvisvgm:
        fail("requires both 'latex' and 'dvisvgm' on PATH")

    document = rf"""\documentclass[border={args.border}pt]{{standalone}}
\usepackage{{amsmath,amssymb}}
\begin{{document}}
\({args.tex}\)
\end{{document}}
"""

    env = os.environ.copy()
    env["openin_any"] = "p"
    env["openout_any"] = "p"

    with tempfile.TemporaryDirectory(prefix="html-visual-reading-latex-") as temp:
        workdir = Path(temp)
        tex_path = workdir / "formula.tex"
        dvi_path = workdir / "formula.dvi"
        svg_path = workdir / "formula.svg"
        tex_path.write_text(document, encoding="utf-8")

        run(
            [latex, "-interaction=nonstopmode", "-halt-on-error", "-no-shell-escape", tex_path.name],
            workdir,
            env,
        )
        run(
            [dvisvgm, "--no-fonts", "--exact", f"--output={svg_path}", str(dvi_path)],
            workdir,
            env,
        )

        rendered = svg_fragment(
            svg_path.read_text(encoding="utf-8"),
            tex=args.tex,
            label=args.label or args.tex,
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered, encoding="utf-8")


if __name__ == "__main__":
    main()
