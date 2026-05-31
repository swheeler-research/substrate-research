#!/usr/bin/env python3
"""
Formal model of the seam criterion, and an exhaustive check of its two
load-bearing claims:

  (1) TEETH: the criterion rejects at least one staging that a reviewer would
      call dangerous (an external commit at a "must-continue" state), i.e. it is
      not satisfied by all stagings.

  (2) NOT ALWAYS SATISFIABLE: there exist operations (an irreversible external
      commit required before a fallible continuation) for which NO staging is
      seam-safe, so the criterion genuinely partitions operations into
      stageable-safely and inherently-unsafe, rather than being vacuously
      satisfiable by rewriting.

This upgrades section 7 from prose to a checked model. It is still a small
finite model, not a general theorem, and is labelled as such.

MODEL
-----
An operation is a finite sequence of acts a_1..a_n. Each act has:
  - ext: bool      (does it commit an externally-visible effect via a governed unit)
  - irrev: bool    (is that external effect irreversible)
A staging assigns each act a commit point; we model the simplest staging where
acts execute in order and the operation may halt after any act (invalidation or
a closing gap). The acceptance policy P labels each post-act state may_stop or
must_continue.

P is constrained by the operation's meaning: an operation "completes" only at
its final act; intermediate states are must_continue unless the policy explicitly
declares an earlier act a valid terminal outcome. We model P as a choice of which
post-act states are may_stop, subject to: the final state is always may_stop
(finishing is acceptable), and the policy cannot label a state may_stop if a
required-later act has an unmet dependency that makes stopping there incoherent.

SEAM-SAFE (the criterion):
  a staging is seam-safe under P iff for every act a_i with ext=True,
  the post-state of a_i is labelled may_stop by P.
"""

from itertools import product

def seam_safe(acts, may_stop):
    """acts: list of dicts with 'ext'. may_stop: tuple of bools per post-state.
       Criterion: every external act's post-state is may_stop."""
    for i, a in enumerate(acts):
        if a["ext"] and not may_stop[i]:
            return False
    return True

def all_policies(n, forced_final_may_stop=True):
    """Enumerate all may_stop labellings of n post-states."""
    for bits in product([False, True], repeat=n):
        if forced_final_may_stop and not bits[-1]:
            continue
        yield bits

def policy_coherent(acts, may_stop):
    """A policy is coherent if it does not label a state may_stop when a strictly
       later act is REQUIRED to repair an irreversible commit made at or before
       that state. Concretely: if an irreversible external commit occurs at act i,
       and there is a required later act j>i (we treat the final act as required),
       then stopping at any state k with i <= k < j strands the irreversible
       commit, so may_stop[k] must be False for the policy to be coherent.
       This encodes 'an acceptable terminal state must not strand an irreversible
       commitment that the operation was required to complete.'"""
    n = len(acts)
    for i, a in enumerate(acts):
        if a["ext"] and a["irrev"]:
            # the operation is required to complete (final act). Any stop at
            # state k in [i, n-2] strands the irreversible commit.
            for k in range(i, n - 1):
                if may_stop[k]:
                    return False
    return True

def has_seam_safe_staging(acts):
    """Is there ANY coherent policy under which the in-order staging is seam-safe?"""
    n = len(acts)
    for ms in all_policies(n):
        if policy_coherent(acts, ms) and seam_safe(acts, ms):
            return True, ms
    return False, None

if __name__ == "__main__":
    print("=== SEAM CRITERION: exhaustive check on small operations ===\n")

    # CLAIM 1: TEETH. A dangerous staging is rejected.
    # Operation: pay (external, reversible) at act 0, then ship at act 1 (final).
    # A policy that labels post-pay 'may_stop' would be incoherent ONLY if the
    # commit were irreversible; here payment is reversible, so the danger is that
    # the policy labels post-pay must_continue (goods not shipped) yet the staging
    # commits the external payment there. The criterion must reject that.
    pay_then_ship = [
        {"name": "pay",  "ext": True,  "irrev": False},
        {"name": "ship", "ext": True,  "irrev": False},
    ]
    # The realistic policy: you may not stop after paying but before shipping.
    realistic = (False, True)  # post-pay must_continue, post-ship may_stop
    print("[TEETH] operation pay->ship, realistic policy (no stop between pay and ship):")
    print("   policy may_stop =", realistic)
    print("   seam-safe? ", seam_safe(pay_then_ship, realistic),
          "  (False = criterion REJECTS the external commit at a must-continue state)")
    print("   -> criterion has teeth: it forbids paying at a point you may not stop at.\n")

    # Is there ANY coherent policy making this operation seam-safe?
    ok, ms = has_seam_safe_staging(pay_then_ship)
    print("   any coherent seam-safe policy for pay->ship?", ok, " policy:", ms)
    print("   (Yes: if the post-pay state can coherently be may_stop, e.g. payment")
    print("    is itself an acceptable terminal outcome. Reversible commit allows this.)\n")

    # CLAIM 2: NOT ALWAYS SATISFIABLE.
    # Operation: pay a NON-REFUNDABLE deposit (external, IRREVERSIBLE) at act 0,
    # then obtain a permit at act 1 (final) which may fail.
    deposit_then_permit = [
        {"name": "deposit", "ext": True,  "irrev": True},
        {"name": "permit",  "ext": False, "irrev": False},
    ]
    ok2, ms2 = has_seam_safe_staging(deposit_then_permit)
    print("[NOT ALWAYS SATISFIABLE] operation: irreversible deposit -> fallible permit:")
    print("   any coherent seam-safe staging?", ok2)
    print("   -> If False: the criterion DETECTS an inherently-unsafe operation,")
    print("      one with no safe staging, exactly as the paper claims. The")
    print("      irreversibility is a property of the world, not fixable by staging.\n")

    # Sanity: an all-internal operation is always seam-safe (no external acts).
    internal = [{"name": "a", "ext": False, "irrev": False},
                {"name": "b", "ext": False, "irrev": False}]
    ok3, ms3 = has_seam_safe_staging(internal)
    print("[SANITY] all-internal operation has a seam-safe staging?", ok3,
          " (expected True: no external commit to strand)\n")

    # Exhaustive sweep: over all operations of length <=3 with ext/irrev flags,
    # confirm the criterion partitions them (some satisfiable, some not).
    print("[PARTITION] sweep all operations length 1..3:")
    sat = unsat = 0
    examples_unsat = []
    for n in (1, 2, 3):
        for flags in product(product([False, True], repeat=2), repeat=n):
            acts = [{"name": f"a{i}", "ext": e, "irrev": ir} for i, (e, ir) in enumerate(flags)]
            ok, _ = has_seam_safe_staging(acts)
            if ok: sat += 1
            else:
                unsat += 1
                if len(examples_unsat) < 3:
                    examples_unsat.append([(a["ext"], a["irrev"]) for a in acts])
    print(f"   satisfiable: {sat}   inherently-unsafe: {unsat}")
    print("   -> the criterion is NEITHER vacuous (all satisfiable) NOR empty (none).")
    print("      It genuinely partitions operations. Example unsafe (ext,irrev) seqs:")
    for ex in examples_unsat:
        print("        ", ex)
    print("\n   NOTE: small finite model. Demonstrates teeth and non-vacuity;")
    print("   not a general theorem. A full treatment would model staging choice")
    print("   and concurrency, and prove the partition for all operations.")
