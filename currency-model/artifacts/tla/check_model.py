#!/usr/bin/env python3
"""
Exhaustive finite-state checker for the single-operator invalidation-surface model.

This is NOT a proof. It is a bounded model check: it enumerates every reachable
state of a small finite instance and verifies the safety invariants on all of
them, refutes the naive invariant by exhibiting a counterexample, confirms the
action property, and checks bounded-enforcement liveness by a cycle/lasso search
under the fairness assumptions. It mirrors what TLC would do on the same instance.

It exists so that the paper's claims are mechanically checked on a small model
here and now, in an environment without TLC, rather than only asserted.
"""

from itertools import product
from collections import deque

# ---- small finite instance ----
# 2 forms, 2 credentials, 1 unit. chain[f0]={c0}, chain[f1]={c0,c1}, both unit u0.
CRED = ["c0", "c1"]
UNIT = ["u0"]
FORM = ["f0", "f1"]
CHAIN = {"f0": frozenset(["c0"]), "f1": frozenset(["c0", "c1"])}
UNITOF = {"f0": "u0", "f1": "u0"}
DELTA = 2
NOW_CAP = DELTA + 2   # bound the clock so the state space is finite

CSTAT = ("valid", "revoked", "superseded", "deprecated")
USTAT = ("active", "deprecated")
WIT = ("ok", "failed")
NONE = -1

# A state is a tuple of immutable, hashable parts:
# (cstatus: tuple per cred, ustatus: tuple per unit, csrcUpdated: frozenset,
#  witness: tuple per form, invocable: tuple per form, now: int,
#  deadline: tuple per form)
# We omit the ledger from the state key for reachability (it grows unboundedly),
# but we track, per transition, whether an Invoke fired and with what tag, so the
# action property and Inv_tagged can be checked on transitions.

def cstatus(s): return dict(zip(CRED, s[0]))
def ustatus(s): return dict(zip(UNIT, s[1]))
def csrc(s): return s[2]
def witness(s): return dict(zip(FORM, s[3]))
def invocable(s): return dict(zip(FORM, s[4]))
def now(s): return s[5]
def deadline(s): return dict(zip(FORM, s[6]))

def affected(s, f):
    cs = cstatus(s)
    if any(cs[c] in ("revoked", "superseded", "deprecated") for c in CHAIN[f]):
        return True
    if ustatus(s)[UNITOF[f]] == "deprecated":
        return True
    if any(c in csrc(s) for c in CHAIN[f]):
        return True
    if witness(s)[f] == "failed":
        return True
    return False

def init_state():
    return (
        tuple("valid" for _ in CRED),
        tuple("active" for _ in UNIT),
        frozenset(),
        tuple("ok" for _ in FORM),
        tuple(True for _ in FORM),
        0,
        tuple(NONE for _ in FORM),
    )

def set_deadlines(s, newly):
    dl = deadline(s)
    nd = []
    for f in FORM:
        if f in newly and dl[f] == NONE:
            nd.append(now(s) + DELTA)
        else:
            nd.append(dl[f])
    return tuple(nd)

def with_(s, cstat=None, ustat=None, csrcU=None, wit=None, inv=None, nw=None, dl=None):
    return (
        cstat if cstat is not None else s[0],
        ustat if ustat is not None else s[1],
        csrcU if csrcU is not None else s[2],
        wit if wit is not None else s[3],
        inv if inv is not None else s[4],
        nw if nw is not None else s[5],
        dl if dl is not None else s[6],
    )

def successors(s):
    """Yield (label, next_state, invoke_info). invoke_info=(form,tag) or None."""
    cs = cstatus(s); us = ustatus(s); wt = witness(s); inv = invocable(s)
    # Triggers
    for c in CRED:
        if cs[c] == "valid":
            ns_cs = tuple("revoked" if cc == c else cs[cc] for cc in CRED)
            tmp = with_(s, cstat=ns_cs)
            newly = {f for f in FORM if c in CHAIN[f]}
            tmp = with_(tmp, dl=set_deadlines(s, newly) if False else None)
            nd = set_deadlines(with_(s, cstat=ns_cs), newly)
            yield ("RevokeCred(%s)" % c, with_(s, cstat=ns_cs, dl=nd), None)
    for u in UNIT:
        if us[u] == "active":
            ns_us = tuple("deprecated" if uu == u else us[uu] for uu in UNIT)
            newly = {f for f in FORM if UNITOF[f] == u}
            nd = set_deadlines(with_(s, ustat=ns_us), newly)
            yield ("DeprecateUnit(%s)" % u, with_(s, ustat=ns_us, dl=nd), None)
    for c in CRED:
        if c not in csrc(s):
            ns_csrc = csrc(s) | {c}
            newly = {f for f in FORM if c in CHAIN[f]}
            nd = set_deadlines(with_(s, csrcU=ns_csrc), newly)
            yield ("UpdateSource(%s)" % c, with_(s, csrcU=ns_csrc, dl=nd), None)
    for f in FORM:
        if wt[f] == "ok":
            ns_wit = tuple("failed" if ff == f else wt[ff] for ff in FORM)
            nd = set_deadlines(with_(s, wit=ns_wit), {f})
            yield ("FailIntegrity(%s)" % f, with_(s, wit=ns_wit, dl=nd), None)
    # Invalidate
    for f in FORM:
        if affected(s, f) and inv[f]:
            ns_inv = tuple(False if ff == f else inv[ff] for ff in FORM)
            ns_dl = tuple(NONE if ff == f else deadline(s)[ff] for ff in FORM)
            yield ("Invalidate(%s)" % f, with_(s, inv=ns_inv, dl=ns_dl), None)
    # Recompile
    for f in FORM:
        if (not inv[f]) and (not affected(s, f)):
            ns_inv = tuple(True if ff == f else inv[ff] for ff in FORM)
            yield ("Recompile(%s)" % f, with_(s, inv=ns_inv), None)
    # Invoke_strict
    for f in FORM:
        if inv[f] and not affected(s, f):
            yield ("Invoke_strict(%s)" % f, s, (f, "clean"))
    # Tick (guarded)
    tick_ok = True
    for f in FORM:
        if affected(s, f) and inv[f] and deadline(s)[f] != NONE and now(s) >= deadline(s)[f]:
            tick_ok = False
            break
    if tick_ok and now(s) < NOW_CAP:
        yield ("Tick", with_(s, nw=now(s) + 1), None)

def inv_bound(s):
    dl = deadline(s); inv = invocable(s)
    for f in FORM:
        if affected(s, f) and inv[f]:
            if not (dl[f] != NONE and now(s) <= dl[f]):
                return False
    return True

def naive_inv(s):
    inv = invocable(s)
    for f in FORM:
        if inv[f] and affected(s, f):
            return False
    return True

# ---- exhaustive reachability ----
def explore():
    start = init_state()
    seen = {start}
    q = deque([start])
    edges = {}  # state -> list of (label, succ, invoke_info)
    bound_violations = []
    naive_counterexample = None
    action_property_violations = []  # an Invoke fired while Affected, or tagged not clean
    while q:
        s = q.popleft()
        succ_list = list(successors(s))
        edges[s] = succ_list
        if not inv_bound(s):
            bound_violations.append(s)
        if naive_counterexample is None and not naive_inv(s):
            naive_counterexample = s
        for label, ns, invk in succ_list:
            if invk is not None:
                f, tag = invk
                # action property: the invoke must occur from a ~Affected state
                if affected(s, f):
                    action_property_violations.append((s, label))
                if tag != "clean":
                    action_property_violations.append((s, label, "bad tag"))
            if ns not in seen:
                seen.add(ns)
                q.append(ns)
    return seen, edges, bound_violations, naive_counterexample, action_property_violations

def describe(s):
    return ("cstatus=%s ustatus=%s csrc=%s witness=%s invocable=%s now=%d deadline=%s"
            % (cstatus(s), ustatus(s), sorted(csrc(s)), witness(s),
               invocable(s), now(s), deadline(s)))

# ---- liveness: every affected form eventually becomes non-invocable ----
# Under weak fairness on Invalidate(f): we check that there is no fair cycle in
# which some form stays (Affected and invocable) forever. Because Invalidate(f)
# is continuously enabled while the form is affected-and-invocable, and WF forces
# it, any cycle keeping the form affected+invocable would have to perpetually
# refuse an enabled Invalidate(f), violating weak fairness. We check the dual:
# is there any reachable cycle (in the unfair transition graph) that keeps some f
# affected+invocable throughout AND in which Invalidate(f) is enabled at every
# state (i.e., WF would force it)? If every such cycle has Invalidate(f) enabled
# throughout, fairness breaks it, so liveness holds. We report any cycle where a
# form is affected+invocable throughout, then confirm Invalidate(f) is enabled in
# all of them (which means fairness excludes them).
def liveness_check(seen, edges):
    # Find strongly-stuck forms: a reachable cycle where some f is affected &
    # invocable at every state. Tarjan SCC over the transition graph.
    index = {}; low = {}; onstack = {}; stack = []; counter = [0]; sccs = []
    import sys as _sys
    _sys.setrecursionlimit(100000)
    def strongconnect(v):
        index[v] = low[v] = counter[0]; counter[0]+=1
        stack.append(v); onstack[v]=True
        for (_, w, _) in edges[v]:
            if w not in index:
                strongconnect(w); low[v]=min(low[v],low[w])
            elif onstack.get(w):
                low[v]=min(low[v],index[w])
        if low[v]==index[v]:
            comp=[]
            while True:
                w=stack.pop(); onstack[w]=False; comp.append(w)
                if w==v: break
            sccs.append(comp)
    for v in seen:
        if v not in index:
            strongconnect(v)
    # A nontrivial SCC (size>1, or self-loop) is a potential infinite behaviour.
    problem = []
    for comp in sccs:
        nontrivial = len(comp) > 1 or any(w==comp[0] for (_,w,_) in edges[comp[0]])
        if not nontrivial:
            continue
        compset = set(comp)
        for f in FORM:
            # f affected+invocable throughout the whole SCC?
            if all(affected(s,f) and invocable(s)[f] for s in comp):
                # Invalidate(f) enabled at every state in comp? (it is iff affected & invocable)
                inval_enabled_everywhere = all(affected(s,f) and invocable(s)[f] for s in comp)
                problem.append((f, comp, inval_enabled_everywhere))
    return problem

if __name__ == "__main__":
    seen, edges, bound_v, naive_ce, ap_v = explore()
    print("=== EXHAUSTIVE FINITE-STATE CHECK ===")
    print("instance: %d forms, %d creds, %d unit, Delta=%d, now_cap=%d"
          % (len(FORM), len(CRED), len(UNIT), DELTA, NOW_CAP))
    print("reachable states explored: %d" % len(seen))
    print()
    print("[Inv_bound] no affected, still-invocable form past its deadline:")
    print("   violations: %d  -> %s" % (len(bound_v), "HOLDS" if not bound_v else "FAILS"))
    print()
    print("[Action property / Inv_tagged] every Invoke_strict fires from ~Affected, tagged clean:")
    print("   violations: %d  -> %s" % (len(ap_v), "HOLDS" if not ap_v else "FAILS"))
    print()
    print("[Naive invariant] invocable => ~Affected  (paper claims this is FALSE):")
    if naive_ce is not None:
        print("   REFUTED, as the paper argues. Counterexample state:")
        print("   " + describe(naive_ce))
        print("   (a form is affected by a trigger but not yet invalidated: the adoption window)")
    else:
        print("   no counterexample found (unexpected)")
    print()
    prob = liveness_check(seen, edges)
    print("[Liveness] every affected form eventually non-invocable, under fairness:")
    if not prob:
        print("   no infinite behaviour keeps a form affected+invocable: HOLDS trivially")
    else:
        allfair = all(p[2] for p in prob)
        print("   %d cycle(s) keep some form affected+invocable throughout." % len(prob))
        print("   In all of them Invalidate(f) is continuously enabled: %s" % allfair)
        if allfair:
            print("   -> weak fairness on Invalidate(f) breaks every such cycle: HOLDS under Fairness")
        else:
            print("   -> a cycle exists where Invalidate is NOT forced: liveness would FAIL")
