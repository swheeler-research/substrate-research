#!/bin/bash
# Rebuild the three paper PDFs with pandoc + xelatex, matching the May 2026 layout.
# Usage: build/build.sh [all|principal|companion|formal]; VERSION=v2.0 by default.
# Outputs land in build/out/; copy to the repository root to publish.
set -e
# Tool locations. Defaults suit a per-user install (see README.md); override by environment.
export PATH=${TEXBIN:-$HOME/texlive/bin/x86_64-linux}:$HOME/bin:$PATH
[ -n "$FONTCONFIG_FILE" ] || { [ -f $HOME/.config/fontconfig/fonts.conf ] && export FONTCONFIG_FILE=$HOME/.config/fontconfig/fonts.conf; }
[ -d $HOME/opt/chromelibs ] && export LD_LIBRARY_PATH=$HOME/opt/chromelibs/usr/lib/x86_64-linux-gnu:$HOME/opt/chromelibs/lib/x86_64-linux-gnu
MMDC=${MMDC:-$HOME/opt/mmdc11/node_modules/.bin/mmdc}
SRC=${SRC:-$(cd "$(dirname "$0")/.." && pwd)}
VERSION=${VERSION:-v2.0}
cd "$(dirname "$0")"
mkdir -p figures out
common=(--from markdown+raw_tex --to pdf --pdf-engine=xelatex --toc --toc-depth=2 --resource-path=.:figures
        -V papersize=a4 -V fontsize=11pt -V "geometry:left=2.5cm,right=2.5cm" -M title="The Sovereign Substrate" -M author="S. Wheeler"
        -V "header-includes=\\newcommand{\\VERSION}{$VERSION}")
if [ "${1:-all}" = all ] || [ "$1" = principal ]; then
  python3 preprocess.py "$SRC/sovereign_substrate_v1_0.md" principal.md figures
  for f in figures/diagram_*.mmd; do
    [ -s "${f%.mmd}.pdf" ] && [ "${f%.mmd}.pdf" -nt "$f" ] && continue
    $MMDC -p puppeteer.json -i "$f" -o "${f%.mmd}.pdf" --pdfFit -w 2000 -H 1400 >/dev/null
  done
  pandoc principal.md "${common[@]}" -H header_principal.tex -V mainfont="DejaVu Serif" -V monofont="DejaVu Sans Mono" \
    -V "geometry:top=2.5cm,bottom=2.5cm" -V linestretch=1.15 -V colorlinks=true -V linkcolor=black -V urlcolor="[RGB]{0,0,102}" --output out/sovereign_substrate_v1_0.pdf && echo built principal
fi
if [ "${1:-all}" = all ] || [ "$1" = companion ]; then
  python3 preprocess.py "$SRC/sovereign_substrate_reference_architecture.md" companion.md figures
  pandoc companion.md "${common[@]}" --shift-heading-level-by=-1 --toc-depth=3 -H header_companion.tex -V "geometry:top=2.8cm,bottom=2.8cm" -V linestretch=1.15 -V mainfont="Latin Modern Roman" -V monofont="Latin Modern Mono" -V monofontoptions="Scale=0.9" \
    -V colorlinks=true -V linkcolor=black -V urlcolor="[RGB]{0,0,128}" --output out/sovereign_substrate_reference_architecture.pdf && echo built companion
fi
if [ "${1:-all}" = all ] || [ "$1" = formal ]; then
  python3 preprocess.py "$SRC/sovereign_substrate_currency_model.md" formal.md figures
  pandoc formal.md "${common[@]}" -H header_formal.tex -V mainfont="DejaVu Serif" -V monofont="DejaVu Sans Mono" -V monofontoptions="Scale=0.85" \
    -V "geometry:top=2.5cm,bottom=2.5cm" -V colorlinks=true -V linkcolor=black -V urlcolor="[RGB]{0,0,128}" --output out/sovereign_substrate_currency_model.pdf && echo built formal
fi
