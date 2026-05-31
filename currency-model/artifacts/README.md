# Proof artifacts

Machine-checked artifacts for *The Sovereign Substrate: A Machine-Checked Model
of Constitutional Currency*. The paper is at
[../../sovereign_substrate_currency_model.pdf](../../sovereign_substrate_currency_model.pdf);
its landing page is [..](../).

## Contents

- `tla/` the TLA+ modules, TLC model-checking configurations, and Python
  cross-checks.
- `transcripts/` the proof-checker and model-checker output, retained as evidence
  so the results can be read without re-running the tools.
- `BUILD.md` reproduction instructions for the TLA+ Proof System, TLC, and the
  paper PDF.

## The headline artifacts

The bounded-latency theorem is `tla/InvSurface_transitive_cascade_tlaps.tla`,
checked by `tlapm` with transcript
`transcripts/tlaps_transitive_cascade_output.txt` (all 301 obligations proved, via
the SMT and LS4 backends). It certifies the safety invariant, the
clock-advancement invariant `BoundInv`, and the bounded-response theorem over all
six invalidation triggers, with the constitutional-source cascade resolved through
the transitive closure of the credential parent relation. Its TLC cross-checks
(`SixTransCheck.tla` with `MCtrans.tla`/`.cfg`, and the depth-two witness
`MCtransNV.cfg`) confirm the safety invariant over the complete reachable graph and
exhibit a multi-level cascade trace.

The invocation-event encoding result rests on `tla/InvalidationSurface.tla`, the
TLC model `tla/MC.tla`/`MC.cfg` (transcripts `tlc_invariants_output.txt` and
`tlc_naive_refutation_output.txt`, the latter printing the counterexample to the
naive state invariant), the independent enumeration `tla/check_model.py`, the seam
check `tla/check_seam.py`, and the certified safety proof
`tla/InvSurface_safety_tlaps.tla` (transcript `tlaps_safety_output.txt`, 65
obligations). The single-trigger lineage `InvSurface_liveness_tlaps.tla` and
`InvSurface_composed_tlaps.tla` is retained as the development the
transitive-cascade model supersedes.

## Licence

Creative Commons Attribution 4.0 International (CC BY 4.0), matching the paper.
