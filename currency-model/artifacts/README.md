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
`transcripts/tlaps_transitive_cascade_output.txt` (all 301 obligations proved: 199
by `tlapm`'s own reasoning, 96 by the SMT backend, and six by LS4). It certifies
the clock-advancement invariant `BoundInv` through theorem `BoundSafety`, the
weakening `NoOvershoot`, and the bounded-response theorem `LiveB` over all six
invalidation triggers, with the constitutional-source cascade resolved through a
`roots` relation constrained by a fixpoint property over the credential parent
relation, which pins the transitive closure for an acyclic relation. Its TLC
cross-checks (`SixTransCheck.tla` with `MCtrans.tla`/`.cfg`, and the depth-two
witness `MCtransNV.cfg`) confirm the safety invariant over the state space
reachable under the configuration's `now <= 3` state constraint and exhibit a
multi-level cascade trace. `SixTransCheck.tla` is the proof module with the proof
apparatus and the assumptions removed, since TLC takes the constants from the
configuration.

The invocation-event encoding result rests on `tla/InvalidationSurface.tla`, the
TLC model `tla/MC.tla` with `MC.cfg` and `MCnaive.cfg` (transcripts
`tlc_invariants_output.txt` and `tlc_naive_refutation_output.txt`, the latter run
under `MCnaive.cfg` and printing the counterexample to the naive state invariant),
a second enumeration `tla/check_model.py`, written against the same model and so
independent of TLC but not of the model, the seam check `tla/check_seam.py`, and
the certified safety proof `tla/InvSurface_safety_tlaps.tla` (transcript
`tlaps_safety_output.txt`, 65 obligations: 50 by `tlapm`'s own reasoning, 14 by the
SMT backend, and one by LS4). The invocation property holds of the model by
construction rather than by model check; its ledger formulation `Inv_tagged` in
`InvalidationSurface.tla` is stated but not checked by any configuration. The single-trigger lineage `InvSurface_liveness_tlaps.tla` and
`InvSurface_composed_tlaps.tla` is retained as the development the
transitive-cascade model supersedes.

## Licence

Creative Commons Attribution 4.0 International (CC BY 4.0), matching the paper.
