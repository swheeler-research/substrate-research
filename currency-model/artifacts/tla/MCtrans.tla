---- MODULE MCtrans ----
EXTENDS SixTransCheck, TLC
CONSTANTS c0, c1, u1, u2, f1, f2
McCred == {c0, c1}
McUnit == {u1, u2}
McForm == {f1, f2}
McSource == {c0}
\* c0 is a constitutional source (parent empty); c1 derives from c0 (parent {c0}).
McParent == (c0 :> {} @@ c1 :> {c0})
\* transitive roots: c0 roots = {c0}; c1 roots = {c0} (through its parent c0).
McRoots == (c0 :> {c0} @@ c1 :> {c0})
\* f1's chain is the DERIVED credential c1 (not c0 directly): cascade must reach f1 via c1.
McChain == (f1 :> {c1} @@ f2 :> {c1})
McUnitOf == (f1 :> u1 @@ f2 :> u2)
McDelta == 2
NowBound == now <= 3
\* Non-vacuity: NOT reachable that f1 invalidated purely via the multi-level cascade.
\* f1's chain has only c1; c1 is not itself updated (c1 not a source); the only way f1
\* is affected via cascade is c0 \in supdated AND c0 \in roots[c1] -- the DEPTH-2 path.
CascadeDepth2 ==
  \A f \in McForm : ~(~invocable[f] /\ supdated # {}
                       /\ (\E c \in chain[f] : \E s \in supdated : s \in roots[c] /\ c # s)
                       /\ crevoked = {} /\ csuperseded = {} /\ cdeprecated = {}
                       /\ drifted = {} /\ integrity[f] = "ok")
====
