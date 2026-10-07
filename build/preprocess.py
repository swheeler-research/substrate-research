#!/usr/bin/env python3
"""Prepare a paper's markdown for pandoc: drop the title block the template
carries, and (for the principal) lift each mermaid block into figures/ and
substitute an includegraphics figure, as the original pipeline did."""
import re, sys, io, os
src, dst, figdir = sys.argv[1], sys.argv[2], sys.argv[3]
s = io.open(src, encoding="utf-8").read()
# title block: everything through the first horizontal rule
if s.startswith("---\n"):            # YAML block first (companion)
    end = s.index("\n---\n", 4) + 5
    s = s[end:]
first_rule = re.search(r"^---\s*$", s, re.M)
if first_rule:
    s = s[first_rule.end():].lstrip("\n")
n = 0
def sub(m):
    global n
    n += 1
    name = "diagram_%02d" % n
    io.open(os.path.join(figdir, name + ".mmd"), "w", encoding="utf-8").write(m.group(1).strip() + "\n")
    return ("\\begin{figure}[H]\n\\centering\n"
            "\\includegraphics[width=\\textwidth, height=0.85\\textheight, keepaspectratio]{figures/%s.pdf}\n"
            "\\end{figure}\n" % name)
s = re.sub(r"```mermaid\n(.*?)```\n", sub, s, flags=re.S)
io.open(dst, "w", encoding="utf-8").write(s)
print("prepared %s: %d diagrams" % (dst, n))
