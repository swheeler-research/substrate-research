# Reproduction

This development was checked with the TLA+ Proof System (`tlapm`) for the proofs
and TLC for the finite-instance model checks. The proofs hold at arbitrary
instance cardinality; the TLC checks exercise bounded instances and produce the
counterexamples. The notes below record the build path used. It is not a
one-command install, so the steps are given in full.

## Proof checking with tlapm

`tlapm` was built from source from the development version of the TLA+ Proof
System.

1. Clone the proof system:

   ```
   git clone --depth 1 https://github.com/tlaplus/tlapm.git
   cd tlapm
   ```

2. Satisfy the build dependencies. OCaml 4.14 with dune was used, plus the usual
   compression and build utilities:

   ```
   apt-get install -y ocaml-nox ocaml-dune zlib1g-dev gawk time
   ```

   The two libraries `tlapm` lists but does not need for the core prover, `re2`
   and `sexp_diff`, are used only by its language server and test harness and were
   not required.

3. Build the prover:

   ```
   dune build src/tlapm.exe
   ```

4. Assemble the backend provers. Zenon and Z3 supply the non-temporal obligations;
   LS4 supplies the temporal (liveness) steps. Place them where `tlapm` looks for
   backends:

   ```
   BK=_build/default/lib/tlapm/backends/bin
   mkdir -p $BK
   cp zenon/zenon $BK/
   cp /usr/local/bin/z3 $BK/z3
   cp deps/ls4/ls4-1.0/core/ls4 $BK/ls4
   cp _build/default/translate/main.exe $BK/ptl_to_trp
   chmod +x $BK/ls4 $BK/ptl_to_trp
   ```

   The backends used were Zenon 0.8.4, Z3 4.16.0, and LS4 with its
   `ptl_to_trp` translator.

5. Check a module, with the backends on the path:

   ```
   export PATH=/tmp/tlapm/_build/default/lib/tlapm/backends/bin:$PATH
   /tmp/tlapm/_build/default/src/tlapm.exe -I /tmp/tlapm/library \
     --toolbox 0 0 InvSurface_transitive_cascade_tlaps.tla
   ```

   The transcript in `transcripts/tlaps_transitive_cascade_output.txt` reports all
   301 obligations proved. The safety module
   `InvSurface_safety_tlaps.tla` reports 65.

## Model checking with TLC

TLC 2.15 was used, obtained through the `tlacli` package on PyPI, which bundles a
complete `tla2tools.jar`:

```
pip install tlacli --break-system-packages
JAR=$(python3 -c "import tlacli, os; print(os.path.join(os.path.dirname(tlacli.__file__), 'tla2tools.jar'))")
java -cp "$JAR" tlc2.TLC -config MC.cfg MC.tla
```

The TLC models are TLA+ specifications stripped of the proof apparatus (they
`EXTENDS Naturals` and `TLC` rather than `TLAPS`, since `:>` and `@@` require the
`TLC` module). The relevant runs:

- `MC.tla` / `MC.cfg`: the single-operator model. Confirms the safety invariant
  and the invocation property over the complete reachable graph, and, run against
  the naive state invariant, prints the counterexample. Transcripts
  `tlc_invariants_output.txt` and `tlc_naive_refutation_output.txt`.
- `SixTransCheck.tla` with `MCtrans.tla` / `MCtrans.cfg`: the transitive-cascade
  model with a two-level credential chain. Confirms the safety invariant over the
  complete reachable graph. Transcript `tlc_transitive_cascade_output.txt`.
- `MCtransNV.cfg`: the depth-two cascade non-vacuity witness. Transcript
  `tlc_transitive_cascade_depth2_output.txt`.

Python cross-checks `check_model.py` and `check_seam.py` run under any Python 3
with no extra packages: `python3 check_model.py`.

## Building the note PDF

The note is built from `note/formal_note.md` with pandoc and xelatex, matching the
parent paper's typography (DejaVu Serif, A4, 11pt, ragged-right body discipline).

```
pandoc formal_note.md \
  --from markdown+raw_tex \
  --to pdf \
  --pdf-engine=xelatex \
  --template=template.tex \
  --toc --toc-depth=2 \
  --output=formal_note.pdf
```

The template requires the `calc` package and the standard pandoc table helper
macros (`\tightlist`, `\real`) for the traceability table to render. The markdown
title block is stripped before the pandoc run, since the template provides its own
title page.
