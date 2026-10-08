# Building the PDFs

The three papers are built from the markdown at the repository root with pandoc and xelatex, the principal paper's twelve mermaid diagrams pre-rendered to PDF by mermaid-cli. This directory holds the pipeline that reproduces the layout of the May 2026 deposits; the templates were reconstructed on 7 October 2026 by measuring those PDFs (fonts, sizes, margins, running heads, line pitch, paragraph and heading spacing, title pages, pagination, link styling, diagram placement) and iterating until every measured value agreed to within a point.

    build/build.sh            # all three, into build/out/
    build/build.sh principal  # one of principal | companion | formal
    VERSION=v2.0 build/build.sh

`preprocess.py` strips each paper's title block (the headers carry the title pages) and lifts each mermaid block into `figures/diagram_NN.mmd`, substituting the figure environment the original pipeline used. The three `header_*.tex` files are pandoc header-includes applied over pandoc's default LaTeX template; the variables that complete each layout are in `build.sh`.

## What each paper's layout is

| | Principal | Reference architecture | Formal companion |
|---|---|---|---|
| Class | article, 11pt, A4 | article, 11pt, A4 | article, 11pt, A4 |
| Body font | DejaVu Serif | Latin Modern Roman | DejaVu Serif |
| Mono font | DejaVu Sans Mono | Latin Modern Mono at 0.9 | DejaVu Sans Mono at 0.85 |
| Margins | 2.5 cm all round | 2.8 cm top and bottom, 2.5 cm sides | 2.5 cm all round |
| Line stretch | 1.15 | 1.15 | none |
| Paragraph skip | 0.5 em | pandoc default | pandoc default |
| Running head | italic title left, page right, no rule | italic title left, version right, rule, page centred in foot | title and version left, page right, rule |
| Headings | H1 section, H2 subsection; tightened spacing; TOC depth 3 | H2 shifted to section; TOC depth 3 | sections at normalsize bold, TOC heading at large; TOC depth 2 |
| Pagination | continuous from the title page; body starts on a fresh page after the contents | title, TOC and body each restart at 1; body on a fresh page | continuous from the title page; body on a fresh page |
| Body alignment | ragged right | justified | justified |
| URLs | monospace, RGB 0 0 102 | monospace, RGB 0 0 128 | monospace, RGB 0 0 128 |

## Toolchain

- pandoc 3.6.4 (static binary from the pandoc releases page).
- TeX Live 2026, xelatex, with fontspec, geometry, fancyhdr, titlesec, hyperref, xurl, microtype, parskip, setspace, float, graphicx, longtable, booktabs, xcolor, fancyvrb, framed, etoolbox, upquote, bookmark, footnotehyper, unicode-math, lm, lm-math, dejavu, iftex, url. A per-user install (`install-tl` with `scheme-basic`, then the packages) is enough; no root needed.
- Fonts: DejaVu (system or TeX Live), Latin Modern (TeX Live), and Liberation Sans for the diagrams, which mermaid's default theme asks for as Arial and fontconfig resolves through its metric aliases. With a per-user fontconfig, point `FONTCONFIG_FILE` at a configuration that lists the TeX Live font directories and the Liberation fonts.
- mermaid-cli 11.x (mermaid 11; the May build used 11.15) with `--pdfFit -w 2000 -H 1400`, driven by puppeteer's Chrome headless shell; `puppeteer.json` passes the no-sandbox flags. mermaid-cli 12 renders a different default look (straight edges, different fills and spacing) and must not be used.
- PyMuPDF, only for the measurement script used during reconstruction; not needed to build.

The build writes `out/*.pdf`; `.gitignore` keeps the intermediates out of the repository. Copy the three outputs to the repository root to publish them.
