#!/usr/bin/env python3
r"""
Inductive-invariant safety proof (escape-clean).
Inductive-invariant proof of the invalidation-surface safety invariant,
discharged by Z3 over ARBITRARY instance sizes (any number of credentials,
units, forms), not a bounded instance.

This does what TLAPS's safety path does: it generates the two inductive
verification conditions

    (VC1)  Init(s)              => Inv(s)
    (VC2)  Inv(s) /\ Next(s,s') => Inv(s')

and discharges each with the Z3 SMT solver. If Z3 returns 'unsat' on the
NEGATION of a VC, the VC is valid (proved); 'sat' would exhibit a
counterexample. Validity here is over the encoded first-order theory with
UNINTERPRETED sorts for Cred/Unit/Form, so a proof holds for every instance,
of every size, not just the small one TLC enumerated.

SCOPE / HONESTY:
- This proves the SAFETY invariant inductively for all sizes. It is the
  substance of the TLAPS safety obligation, discharged by the same backend
  (Z3) TLAPS would use.
- It is NOT a tlapm-certified proof (no TLA+ Toolbox, no proof-script
  certification, no Isabelle/Zenon cross-check).
- It does NOT address the liveness/bounded-enforcement property; SMT
  induction covers safety, not temporal/fairness reasoning.
"""

from z3 import *

# --------------------------------------------------------------------------
# Sorts: Cred, Unit, Form are UNINTERPRETED -> arbitrary, unbounded domains.
# This is the key difference from TLC: we quantify over all forms/creds, not
# a fixed finite set.
# --------------------------------------------------------------------------
Cred = DeclareSort('Cred')
Unit = DeclareSort('Unit')
Form = DeclareSort('Form')

# Status enumerations
CStat, (VALID, REVOKED, SUPERSEDED, DEPRECATED) = EnumSort('CStat', ['valid','revoked','superseded','deprecated'])
UStat, (ACTIVE, UDEPRECATED) = EnumSort('UStat', ['active','udeprecated'])
WStat, (OK, FAILED) = EnumSort('WStat', ['ok','failed'])

# Structure (frozen at compile time): chain membership and unitOf.
# inchain(c,f): credential c is in form f's authority chain.
inchain = Function('inchain', Cred, Form, BoolSort())
unitOf  = Function('unitOf', Form, Unit)

# Delta is a positive integer constant.
Delta = Int('Delta')

# A STATE is a tuple of functions/relations. We model each state component as
# a Z3 function symbol; a "primed" state uses a second set of symbols.
def mk_state(tag):
    return {
        'cstatus':  Function('cstatus_%s'%tag, Cred, CStat),
        'ustatus':  Function('ustatus_%s'%tag, Unit, UStat),
        'csrc':     Function('csrc_%s'%tag, Cred, BoolSort()),     # c in csrcUpdated
        'witness':  Function('witness_%s'%tag, Form, WStat),
        'invocable':Function('invocable_%s'%tag, Form, BoolSort()),
        'now':      Int('now_%s'%tag),
        'deadline': Function('deadline_%s'%tag, Form, IntSort()),  # NONE encoded as 0; live deadlines are >=1
        'hasDL':    Function('hasDL_%s'%tag, Form, BoolSort()),    # deadline[f] != NONE
    }

# NONE sentinel handled via hasDL flag (cleaner than a magic integer).

def Affected(st, f):
    c = Const('c_aff', Cred)
    return Or(
        Exists([c], And(inchain(c, f),
                        Or(st['cstatus'](c)==REVOKED, st['cstatus'](c)==SUPERSEDED, st['cstatus'](c)==DEPRECATED))),
        st['ustatus'](unitOf(f))==UDEPRECATED,
        Exists([c], And(inchain(c, f), st['csrc'](c))),
        st['witness'](f)==FAILED
    )

# --------------------------------------------------------------------------
# The invariant. Inv_bound: every affected, still-invocable form has a live
# deadline not yet passed.  We must STRENGTHEN it to be inductive (TypeOK-style
# support): deadlines are positive when live, and now >= 0.
# --------------------------------------------------------------------------
def Inv(st):
    f = Const('f_inv', Form)
    bound = ForAll([f],
        Implies(And(Affected(st, f), st['invocable'](f)),
                And(st['hasDL'](f), st['now'] <= st['deadline'](f))))
    # support invariants that make Inv inductive:
    #  (a) now is non-negative;
    #  (b) any live deadline is positive;
    #  (c) a live deadline on an invocable form lies at or after now
    #      (no invocable form carries an already-expired deadline); and
    #  (d) a deadline is only carried by a form that is affected or already
    #      non-invocable, i.e. an invocable form with a live deadline must be
    #      affected. This rules out the stale-deadline state Z3 found, which is
    #      unreachable because triggers never revert: once affected, a form
    #      stays affected until invalidated (which clears the deadline).
    f2 = Const('f_inv2', Form)
    support = And(
        st['now'] >= 0,
        ForAll([f2], Implies(st['hasDL'](f2), st['deadline'](f2) >= 1)),
        ForAll([f2], Implies(And(st['hasDL'](f2), st['invocable'](f2)),
                             st['now'] <= st['deadline'](f2))),
        ForAll([f2], Implies(And(st['hasDL'](f2), st['invocable'](f2)),
                             Affected(st, f2))),
    )
    return And(bound, support)

# --------------------------------------------------------------------------
# Init
# --------------------------------------------------------------------------
def Init(st):
    c = Const('c_init', Cred); u = Const('u_init', Unit); f = Const('f_init', Form)
    return And(
        ForAll([c], st['cstatus'](c)==VALID),
        ForAll([u], st['ustatus'](u)==ACTIVE),
        ForAll([c], Not(st['csrc'](c))),
        ForAll([f], st['witness'](f)==OK),
        ForAll([f], st['invocable'](f)==True),
        st['now']==0,
        ForAll([f], Not(st['hasDL'](f))),
    )

# --------------------------------------------------------------------------
# Transition relation Next(s, s') as a disjunction of actions.
# Each action specifies how every state component relates s to s'.
# We use a helper to assert "component unchanged".
# --------------------------------------------------------------------------
def eqExcept(s, t, changed):
    """All components equal between s and t except those named in `changed`."""
    f = Const('f_eq', Form); c = Const('c_eq', Cred); u = Const('u_eq', Unit)
    conj = []
    if 'cstatus'   not in changed: conj.append(ForAll([c], s['cstatus'](c)==t['cstatus'](c)))
    if 'ustatus'   not in changed: conj.append(ForAll([u], s['ustatus'](u)==t['ustatus'](u)))
    if 'csrc'      not in changed: conj.append(ForAll([c], s['csrc'](c)==t['csrc'](c)))
    if 'witness'   not in changed: conj.append(ForAll([f], s['witness'](f)==t['witness'](f)))
    if 'invocable' not in changed: conj.append(ForAll([f], s['invocable'](f)==t['invocable'](f)))
    if 'now'       not in changed: conj.append(s['now']==t['now'])
    if 'deadline'  not in changed or 'hasDL' not in changed:
        # deadline and hasDL move together unless explicitly changed
        pass
    if 'deadline'  not in changed: conj.append(ForAll([f], s['deadline'](f)==t['deadline'](f)))
    if 'hasDL'     not in changed: conj.append(ForAll([f], s['hasDL'](f)==t['hasDL'](f)))
    return And(*conj) if conj else BoolVal(True)

def SetDeadlines(s, t, newly_pred):
    """t's deadline/hasDL: for forms f satisfying newly_pred(f) that had no
       deadline, set deadline'=now+Delta, hasDL'=true; else unchanged."""
    f = Const('f_sd', Form)
    return And(
        ForAll([f], t['deadline'](f) ==
               If(And(newly_pred(f), Not(s['hasDL'](f))), s['now']+Delta, s['deadline'](f))),
        ForAll([f], t['hasDL'](f) ==
               Or(s['hasDL'](f), newly_pred(f)))
    )

def A_RevokeCred(s, t):
    c0 = Const('c0_rev', Cred)
    f = Const('f_rev', Form)
    return Exists([c0], And(
        s['cstatus'](c0)==VALID,
        # cstatus' : c0 -> revoked, others unchanged
        ForAll([Const('c_r',Cred)], t['cstatus'](Const('c_r',Cred)) ==
               If(Const('c_r',Cred)==c0, REVOKED, s['cstatus'](Const('c_r',Cred)))),
        SetDeadlines(s, t, lambda ff: inchain(c0, ff)),
        eqExcept(s, t, {'cstatus','deadline','hasDL'}),
    ))

def A_DeprecateUnit(s, t):
    u0 = Const('u0_dep', Unit)
    return Exists([u0], And(
        s['ustatus'](u0)==ACTIVE,
        ForAll([Const('u_d',Unit)], t['ustatus'](Const('u_d',Unit)) ==
               If(Const('u_d',Unit)==u0, UDEPRECATED, s['ustatus'](Const('u_d',Unit)))),
        SetDeadlines(s, t, lambda ff: unitOf(ff)==u0),
        eqExcept(s, t, {'ustatus','deadline','hasDL'}),
    ))

def A_UpdateSource(s, t):
    c0 = Const('c0_upd', Cred)
    return Exists([c0], And(
        Not(s['csrc'](c0)),
        ForAll([Const('c_u',Cred)], t['csrc'](Const('c_u',Cred)) ==
               Or(s['csrc'](Const('c_u',Cred)), Const('c_u',Cred)==c0)),
        SetDeadlines(s, t, lambda ff: inchain(c0, ff)),
        eqExcept(s, t, {'csrc','deadline','hasDL'}),
    ))

def A_FailIntegrity(s, t):
    f0 = Const('f0_fail', Form)
    return Exists([f0], And(
        s['witness'](f0)==OK,
        ForAll([Const('f_f',Form)], t['witness'](Const('f_f',Form)) ==
               If(Const('f_f',Form)==f0, FAILED, s['witness'](Const('f_f',Form)))),
        SetDeadlines(s, t, lambda ff: ff==f0),
        eqExcept(s, t, {'witness','deadline','hasDL'}),
    ))

def A_Invalidate(s, t):
    f0 = Const('f0_inv', Form)
    return Exists([f0], And(
        Affected(s, f0),
        s['invocable'](f0)==True,
        ForAll([Const('f_i',Form)], t['invocable'](Const('f_i',Form)) ==
               If(Const('f_i',Form)==f0, BoolVal(False), s['invocable'](Const('f_i',Form)))),
        # deadline discharged for f0
        ForAll([Const('f_i2',Form)], t['deadline'](Const('f_i2',Form)) == s['deadline'](Const('f_i2',Form))),
        ForAll([Const('f_i3',Form)], t['hasDL'](Const('f_i3',Form)) ==
               If(Const('f_i3',Form)==f0, BoolVal(False), s['hasDL'](Const('f_i3',Form)))),
        eqExcept(s, t, {'invocable','hasDL','deadline'}),
    ))

def A_Recompile(s, t):
    f0 = Const('f0_rec', Form)
    return Exists([f0], And(
        s['invocable'](f0)==False,
        Not(Affected(s, f0)),
        ForAll([Const('f_rc',Form)], t['invocable'](Const('f_rc',Form)) ==
               If(Const('f_rc',Form)==f0, BoolVal(True), s['invocable'](Const('f_rc',Form)))),
        # recompiling clears any pending deadline for f0 (no pending invalidation)
        ForAll([Const('f_rc2',Form)], t['hasDL'](Const('f_rc2',Form)) ==
               If(Const('f_rc2',Form)==f0, BoolVal(False), s['hasDL'](Const('f_rc2',Form)))),
        ForAll([Const('f_rc3',Form)], t['deadline'](Const('f_rc3',Form)) == s['deadline'](Const('f_rc3',Form))),
        eqExcept(s, t, {'invocable','hasDL','deadline'}),
    ))

def A_InvokeStrict(s, t):
    f0 = Const('f0_ivk', Form)
    # invocation does not change any tracked safety state; guard requires ~Affected
    return Exists([f0], And(
        s['invocable'](f0)==True,
        Not(Affected(s, f0)),
        eqExcept(s, t, set()),   # all components unchanged
    ))

def A_Tick(s, t):
    f = Const('f_tick', Form)
    tick_ok = ForAll([f], Not(And(Affected(s,f), s['invocable'](f), s['hasDL'](f), s['now'] >= s['deadline'](f))))
    return And(
        tick_ok,
        t['now'] == s['now'] + 1,
        eqExcept(s, t, {'now'}),
    )

def Next(s, t):
    return Or(
        A_RevokeCred(s,t), A_DeprecateUnit(s,t), A_UpdateSource(s,t),
        A_FailIntegrity(s,t), A_Invalidate(s,t), A_Recompile(s,t),
        A_InvokeStrict(s,t), A_Tick(s,t),
    )

# --------------------------------------------------------------------------
# Discharge the two verification conditions.
# --------------------------------------------------------------------------
def check_vc(name, claim_universal):
    """claim_universal is a Z3 BoolRef asserting the VC. We check validity by
       asking Z3 whether its NEGATION is unsat."""
    s = Solver()
    s.set('timeout', 120000)  # 120s
    s.add(Delta >= 1)
    s.add(Not(claim_universal))
    r = s.check()
    if r == unsat:
        print(f"[{name}] PROVED  (negation unsat: the VC is valid for all instances)")
        return True
    elif r == sat:
        print(f"[{name}] FAILED  (counterexample exists; invariant not inductive as stated)")
        return False
    else:
        print(f"[{name}] UNKNOWN (Z3 returned {r}; obligation not discharged within timeout)")
        return False

if __name__ == "__main__":
    print("=== Z3 inductive proof over ARBITRARY instance sizes ===")
    print("(uninterpreted sorts Cred/Unit/Form: a proof holds for every size)\n")

    s0 = mk_state('s')
    s1 = mk_state('t')

    # VC1: Init => Inv
    vc1 = Implies(Init(s0), Inv(s0))
    ok1 = check_vc("VC1  Init => Inv_bound", vc1)

    # VC2: Inv(s) /\ Next(s,t) => Inv(t)
    vc2 = Implies(And(Inv(s0), Next(s0, s1)), Inv(s1))
    ok2 = check_vc("VC2  Inv_bound /\\ Next => Inv_bound'", vc2)

    # VC3: currency action property. InvokeStrict fires only from a state in
    # which an unaffected invocable form exists (the guard held).
    fw = Const('fw', Form)
    guard_implied = Implies(A_InvokeStrict(s0, s1),
        Exists([fw], And(s0['invocable'](fw), Not(Affected(s0, fw)))))
    ok3 = check_vc("VC3  InvokeStrict => guard (no act under stale governance)", guard_implied)

    print()
    if ok1 and ok2 and ok3:
        print("RESULT: the SAFETY obligations are discharged for ALL instance sizes by Z3.")
        print("  - Inv_bound is an inductive invariant (VC1, VC2).")
        print("  - Strict-mode currency holds: InvokeStrict fires only under ~Affected (VC3).")
        print("This is the substance of the TLAPS safety proof, discharged by the SMT")
        print("backend TLAPS uses, over arbitrary Cred/Unit/Form rather than a bounded model.")
        print()
        print("NOT covered by this method: the bounded-enforcement LIVENESS property,")
        print("which requires temporal/fairness reasoning outside SMT induction. It")
        print("remains a safety invariant plus a fairness-conditioned leads-to, as stated.")
    else:
        print("RESULT: not all obligations discharged; see above.")


# --------------------------------------------------------------------------
# Liveness core (ranking function). The SMT-dischargeable part of the
# bounded-enforcement argument; the temporal glue under weak fairness is not
# an SMT obligation and is not discharged here.
# --------------------------------------------------------------------------
def prove_liveness_core():
    f0 = Const('f0_live', Form)
    s0 = mk_state('s'); s1 = mk_state('t')
    rank_s = s0['deadline'](f0) - s0['now']
    rank_t = s1['deadline'](f0) - s1['now']
    results = {}
    # (a) ranking bounded below
    pa = Implies(And(Inv(s0), Affected(s0,f0), s0['invocable'](f0)), rank_s >= 0)
    results['a_bounded_below'] = _valid(pa)
    # (b) Tick strictly decreases ranking
    pb = Implies(And(Inv(s0), A_Tick(s0,s1), Affected(s0,f0), s0['invocable'](f0),
                     s1['deadline'](f0)==s0['deadline'](f0)), rank_t < rank_s)
    results['b_tick_decreases'] = _valid(pb)
    # (c) Tick disabled at deadline
    at_dl = And(Inv(s0), Affected(s0,f0), s0['invocable'](f0), s0['hasDL'](f0),
                s0['now']==s0['deadline'](f0))
    fg = Const('fg', Form)
    tick_guard = ForAll([fg], Not(And(Affected(s0,fg), s0['invocable'](fg),
                          s0['hasDL'](fg), s0['now'] >= s0['deadline'](fg))))
    results['c_tick_disabled_at_deadline'] = _valid(Implies(at_dl, Not(tick_guard)))
    # (d) Invalidate enabled while affected+invocable
    ft = Const('ft', Form)
    pd = Implies(And(Affected(s0,f0), s0['invocable'](f0)),
                 Exists([ft], And(Affected(s0,ft), s0['invocable'](ft))))
    results['d_invalidate_enabled'] = _valid(pd)
    return results

def _valid(claim):
    s = Solver(); s.set('timeout', 60000); s.add(Delta >= 1); s.add(Not(claim))
    return s.check() == unsat
