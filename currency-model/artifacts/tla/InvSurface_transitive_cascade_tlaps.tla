---- MODULE SixTrigTransitive ----
\* The uniform invalidation surface with all six triggers modelled as distinct
\* actions carrying their real structure. We prove: (safety) no affected, invocable
\* form is past its deadline and deadlines are within Delta; (bounded response)
\* every affected, invocable form becomes non-invocable by clock-time deadline,
\* which is trigger-time + Delta -- for ALL six triggers uniformly, including the
\* constitutional-source cascade through transitive authority chains.
EXTENDS Naturals, TLAPS

CONSTANTS
    Cred,          \* credential units
    Unit,          \* functional/state units
    Form,          \* compiled forms
    Source,        \* constitutional source credentials (subset of Cred, provenance length 0)
    Delta,         \* the latency bound
    chain,         \* chain[f] : the set of credentials in form f's authority chain
    unitOf,        \* unitOf[f] : the unit form f compiles
    parent,        \* parent[c] : immediate parent credentials of c (provenance chain)
    roots          \* roots[c]  : constitutional sources transitively reachable from c

VARIABLES
    crevoked,      \* set of revoked credentials                  (trigger 1)
    csuperseded,   \* set of superseded credentials               (trigger 2)
    cdeprecated,   \* set of deprecated credentials or units       (trigger 3)
    supdated,      \* set of updated constitutional sources         (trigger 4: cascade)
    drifted,       \* set of units whose behaviour has drifted      (trigger 5)
    integrity,     \* integrity[f] : "ok" or "failed"               (trigger 6)
    invocable,     \* invocable[f] : BOOLEAN
    now,           \* governance clock
    deadline,      \* deadline[f] : Nat
    hasDL          \* hasDL[f] : BOOLEAN (a live deadline is set)

NoneDL == 0

\* A form is affected if ANY of the six triggers touches it. This is the uniform
\* surface: six operationally distinct conditions, one predicate, one enforcement.
\* The constitutional-update disjunct is the cascade: a form is affected if ANY
\* credential in its chain is anchored at an updated constitutional source.
Affected(f) ==
    \/ \E c \in chain[f] : c \in crevoked                          \* (1) revocation
    \/ \E c \in chain[f] : c \in csuperseded                       \* (2) supersession
    \/ \E c \in chain[f] : c \in cdeprecated                       \* (3) deprecation
    \/ unitOf[f] \in cdeprecated                                   \* (3) unit deprecation
    \/ \E c \in chain[f] : \E s \in supdated : s \in roots[c]      \* (4) transitive cascade
    \/ unitOf[f] \in drifted                                       \* (5) drift
    \/ integrity[f] = "failed"                                     \* (6) integrity

TypeOK ==
    /\ crevoked \in SUBSET Cred
    /\ csuperseded \in SUBSET Cred
    /\ cdeprecated \in SUBSET (Cred \cup Unit)
    /\ supdated \in SUBSET Source
    /\ drifted \in SUBSET Unit
    /\ integrity \in [Form -> {"ok","failed"}]
    /\ invocable \in [Form -> BOOLEAN]
    /\ now \in Nat
    /\ deadline \in [Form -> Nat]
    /\ hasDL \in [Form -> BOOLEAN]

Init ==
    /\ crevoked = {} /\ csuperseded = {} /\ cdeprecated = {}
    /\ supdated = {} /\ drifted = {}
    /\ integrity = [f \in Form |-> "ok"]
    /\ invocable = [f \in Form |-> TRUE]
    /\ now = 0
    /\ deadline = [f \in Form |-> NoneDL]
    /\ hasDL = [f \in Form |-> FALSE]

\* When a trigger fires, every newly-affected form that does not yet have a live
\* deadline gets one set to now + Delta. This is the uniform surface response.
SetDL(na) ==
    /\ deadline' = [f \in Form |-> IF f \in na /\ ~hasDL[f] THEN now + Delta ELSE deadline[f]]
    /\ hasDL' = [f \in Form |-> hasDL[f] \/ (f \in na)]

\* Newly-affected forms under a trigger: forms that become affected by this event.
\* We arm deadlines for ALL forms that are affected after the trigger but were not
\* before. Simplest faithful encoding: arm any form that is affected in the post
\* state. SetDL only sets a deadline if ~hasDL, so re-arming is idempotent.

vars == <<crevoked, csuperseded, cdeprecated, supdated, drifted, integrity,
          invocable, now, deadline, hasDL>>

\* ---- The six triggers, each a distinct action ----

RevokeCred(c) ==
    /\ c \notin crevoked
    /\ crevoked' = crevoked \cup {c}
    /\ SetDL({f \in Form : c \in chain[f]})
    /\ UNCHANGED <<csuperseded, cdeprecated, supdated, drifted, integrity, invocable, now>>

SupersedeCred(c) ==
    /\ c \notin csuperseded
    /\ csuperseded' = csuperseded \cup {c}
    /\ SetDL({f \in Form : c \in chain[f]})
    /\ UNCHANGED <<crevoked, cdeprecated, supdated, drifted, integrity, invocable, now>>

Deprecate(x) ==
    /\ x \notin cdeprecated
    /\ cdeprecated' = cdeprecated \cup {x}
    /\ SetDL({f \in Form : x \in chain[f] \/ unitOf[f] = x})
    /\ UNCHANGED <<crevoked, csuperseded, supdated, drifted, integrity, invocable, now>>

\* The cascade. Updating a constitutional source affects EVERY form whose chain
\* contains a credential anchored at that source -- transitively, because anchor[]
\* already resolves each credential to its constitutional source. The newly-affected
\* set is all forms with some chain credential anchored at s.
UpdateSource(s) ==
    /\ s \notin supdated
    /\ supdated' = supdated \cup {s}
    /\ SetDL({f \in Form : \E c \in chain[f] : s \in roots[c]})
    /\ UNCHANGED <<crevoked, csuperseded, cdeprecated, drifted, integrity, invocable, now>>

DriftUnit(u) ==
    /\ u \notin drifted
    /\ drifted' = drifted \cup {u}
    /\ SetDL({f \in Form : unitOf[f] = u})
    /\ UNCHANGED <<crevoked, csuperseded, cdeprecated, supdated, integrity, invocable, now>>

FailIntegrity(f) ==
    /\ integrity[f] = "ok"
    /\ integrity' = [integrity EXCEPT ![f] = "failed"]
    /\ SetDL({f})
    /\ UNCHANGED <<crevoked, csuperseded, cdeprecated, supdated, drifted, invocable, now>>

\* ---- Enforcement, recompilation, clock ----

Invalidate(f) ==
    /\ Affected(f) /\ invocable[f] = TRUE
    /\ invocable' = [invocable EXCEPT ![f] = FALSE]
    /\ hasDL' = [hasDL EXCEPT ![f] = FALSE]
    /\ deadline' = deadline
    /\ UNCHANGED <<crevoked, csuperseded, cdeprecated, supdated, drifted, integrity, now>>

Recompile(f) ==
    /\ invocable[f] = FALSE /\ ~Affected(f)
    /\ invocable' = [invocable EXCEPT ![f] = TRUE]
    /\ hasDL' = [hasDL EXCEPT ![f] = FALSE]
    /\ deadline' = deadline
    /\ UNCHANGED <<crevoked, csuperseded, cdeprecated, supdated, drifted, integrity, now>>

InvokeStrict(f) ==
    /\ invocable[f] = TRUE /\ ~Affected(f)
    /\ UNCHANGED vars

TickOK == \A f \in Form : ~(Affected(f) /\ invocable[f] /\ hasDL[f] /\ now >= deadline[f])
Tick ==
    /\ TickOK
    /\ now' = now + 1
    /\ UNCHANGED <<crevoked, csuperseded, cdeprecated, supdated, drifted, integrity,
                   invocable, deadline, hasDL>>

Next ==
    \/ \E c \in Cred : RevokeCred(c)
    \/ \E c \in Cred : SupersedeCred(c)
    \/ \E x \in (Cred \cup Unit) : Deprecate(x)
    \/ \E s \in Source : UpdateSource(s)
    \/ \E u \in Unit : DriftUnit(u)
    \/ \E f \in Form : FailIntegrity(f)
    \/ \E f \in Form : Invalidate(f)
    \/ \E f \in Form : Recompile(f)
    \/ \E f \in Form : InvokeStrict(f)
    \/ Tick

WFInv(ff) == WF_vars(Invalidate(ff))
Fairness == \A f \in Form : WFInv(f)
Spec  == Init /\ [][Next]_vars
SpecL == Init /\ [][Next]_vars /\ Fairness

ASSUME DeltaAsm  == Delta \in Nat /\ Delta >= 1
ASSUME ChainAsm  == chain \in [Form -> SUBSET Cred]
ASSUME UnitOfAsm == unitOf \in [Form -> Unit]
ASSUME ParentAsm == parent \in [Cred -> SUBSET Cred]
ASSUME RootsType  == roots \in [Cred -> SUBSET Source]
\* roots[] IS the transitive closure of parent[] over constitutional sources:
\* a source s is a transitive root of c iff c is itself that source, or some
\* immediate parent of c has s as a transitive root. This fixpoint characterisation
\* is what makes the cascade genuinely multi-level rather than one-step.
ASSUME RootsClosure ==
  \A c \in Cred : \A s \in Source :
     (s \in roots[c]) <=> ( (c = s) \/ (\E p \in parent[c] : s \in roots[p]) )

\* ===========================================================================
\* SAFETY: the bound invariant. No affected, invocable form is past its deadline,
\* and every live deadline of an invocable form is within Delta of the clock.
\* Proved inductively over all ten actions (six triggers + invalidate/recompile/
\* invoke/tick), for arbitrary instance cardinality.
\* ===========================================================================
BoundInv ==
    /\ TypeOK
    /\ \A f \in Form : (Affected(f) /\ invocable[f]) => (hasDL[f] /\ now <= deadline[f])
    /\ \A f \in Form : (hasDL[f] /\ invocable[f]) => Affected(f)
    /\ \A f \in Form : (hasDL[f] /\ invocable[f]) => now <= deadline[f]
    /\ \A f \in Form : (hasDL[f] /\ invocable[f]) => deadline[f] <= now + Delta

THEOREM BoundSafety == Spec => []BoundInv
<1> USE DeltaAsm, ChainAsm, UnitOfAsm, ParentAsm, RootsType, RootsClosure
<1>1. Init => BoundInv
  BY DEF Init, BoundInv, TypeOK, Affected, NoneDL
<1>2. BoundInv /\ [Next]_vars => BoundInv'
  <2> SUFFICES ASSUME BoundInv, [Next]_vars PROVE BoundInv'  OBVIOUS
  <2>1. CASE UNCHANGED vars  BY <2>1 DEF BoundInv, TypeOK, Affected, vars
  <2>2. ASSUME NEW c \in Cred, RevokeCred(c) PROVE BoundInv'
    BY <2>2 DEF BoundInv, TypeOK, Affected, RevokeCred, SetDL
  <2>3. ASSUME NEW c \in Cred, SupersedeCred(c) PROVE BoundInv'
    BY <2>3 DEF BoundInv, TypeOK, Affected, SupersedeCred, SetDL
  <2>4. ASSUME NEW x \in (Cred \cup Unit), Deprecate(x) PROVE BoundInv'
    BY <2>4 DEF BoundInv, TypeOK, Affected, Deprecate, SetDL
  <2>5. ASSUME NEW s \in Source, UpdateSource(s) PROVE BoundInv'
    BY <2>5 DEF BoundInv, TypeOK, Affected, UpdateSource, SetDL
  <2>6. ASSUME NEW u \in Unit, DriftUnit(u) PROVE BoundInv'
    BY <2>6 DEF BoundInv, TypeOK, Affected, DriftUnit, SetDL
  <2>7. ASSUME NEW f \in Form, FailIntegrity(f) PROVE BoundInv'
    BY <2>7 DEF BoundInv, TypeOK, Affected, FailIntegrity, SetDL
  <2>8. ASSUME NEW f \in Form, Invalidate(f) PROVE BoundInv'
    BY <2>8 DEF BoundInv, TypeOK, Affected, Invalidate
  <2>9. ASSUME NEW f \in Form, Recompile(f) PROVE BoundInv'
    BY <2>9 DEF BoundInv, TypeOK, Affected, Recompile
  <2>10. ASSUME NEW f \in Form, InvokeStrict(f) PROVE BoundInv'
    BY <2>10 DEF BoundInv, TypeOK, Affected, InvokeStrict, vars
  <2>11. CASE Tick  BY <2>11 DEF BoundInv, TypeOK, Affected, Tick, TickOK
  <2>12. QED
    BY <2>1,<2>2,<2>3,<2>4,<2>5,<2>6,<2>7,<2>8,<2>9,<2>10,<2>11 DEF Next
<1>3. QED  BY <1>1, <1>2, PTL DEF Spec

NoOvershoot ==
    \A f \in Form : (Affected(f) /\ invocable[f]) => (now <= deadline[f] /\ deadline[f] <= now + Delta)

THEOREM BoundedLatency == Spec => []NoOvershoot
<1> USE DeltaAsm, ChainAsm, UnitOfAsm, ParentAsm, RootsType, RootsClosure
<1>1. BoundInv => NoOvershoot  BY DEF BoundInv, NoOvershoot
<1>2. QED  BY <1>1, BoundSafety, PTL DEF NoOvershoot


\* ===========================================================================
\* LIVENESS SUPPORT LEMMAS
\* ===========================================================================

\* Type invariant carried into the liveness argument.
LEMMA TypeCorrect == SpecL => []TypeOK
<1> USE DeltaAsm, ChainAsm, UnitOfAsm, ParentAsm, RootsType, RootsClosure
<1>1. Init => TypeOK  BY DEF Init, TypeOK, NoneDL
<1>2. TypeOK /\ [Next]_vars => TypeOK'
  BY DEF TypeOK, Next, vars, RevokeCred, SupersedeCred, Deprecate, UpdateSource,
         DriftUnit, FailIntegrity, Invalidate, Recompile, InvokeStrict, Tick, SetDL
<1> QED  BY <1>1, <1>2, PTL DEF SpecL

\* Invalidation is enabled whenever a form is affected and invocable.
LEMMA EnabledInval ==
  ASSUME TypeOK, NEW f \in Form, Affected(f), invocable[f]
  PROVE  ENABLED <<Invalidate(f)>>_vars
<1> USE DeltaAsm
<1> QED  BY ExpandENABLED DEF Invalidate, vars, TypeOK



\* The per-step leadsto premise, with Affected monotonicity proved per trigger.
LEMMA StepLeadsto ==
  ASSUME TypeOK, NEW f \in Form, Affected(f), invocable[f], [Next]_vars
  PROVE  (Affected(f) /\ invocable[f])' \/ ~(invocable[f]')
<1> USE DeltaAsm, ChainAsm, UnitOfAsm, ParentAsm, RootsType, RootsClosure
<1> DEFINE P == Affected(f) /\ invocable[f]
\* For each trigger, invocable[f] is unchanged and Affected(f) is preserved because
\* the trigger only grows a monotone set; so P' holds.
<1>1. CASE UNCHANGED vars  BY <1>1 DEF vars, Affected
<1>2. ASSUME NEW c \in Cred, RevokeCred(c) PROVE P'
  <2>1. invocable' = invocable /\ crevoked \subseteq crevoked'
    BY <1>2 DEF RevokeCred
  <2>2. csuperseded'=csuperseded /\ cdeprecated'=cdeprecated /\ supdated'=supdated
        /\ drifted'=drifted /\ integrity'=integrity
    BY <1>2 DEF RevokeCred, SetDL
  <2>3. Affected(f)'  BY <2>1, <2>2 DEF Affected
  <2> QED  BY <2>1, <2>3 DEF Affected
<1>3. ASSUME NEW c \in Cred, SupersedeCred(c) PROVE P'
  <2>1. invocable' = invocable /\ csuperseded \subseteq csuperseded'  BY <1>3 DEF SupersedeCred
  <2>2. crevoked'=crevoked /\ cdeprecated'=cdeprecated /\ supdated'=supdated
        /\ drifted'=drifted /\ integrity'=integrity  BY <1>3 DEF SupersedeCred, SetDL
  <2>3. Affected(f)'  BY <2>1, <2>2 DEF Affected
  <2> QED  BY <2>1, <2>3 DEF Affected
<1>4. ASSUME NEW x \in (Cred \cup Unit), Deprecate(x) PROVE P'
  <2>1. invocable' = invocable /\ cdeprecated \subseteq cdeprecated'  BY <1>4 DEF Deprecate
  <2>2. crevoked'=crevoked /\ csuperseded'=csuperseded /\ supdated'=supdated
        /\ drifted'=drifted /\ integrity'=integrity  BY <1>4 DEF Deprecate, SetDL
  <2>3. Affected(f)'  BY <2>1, <2>2 DEF Affected
  <2> QED  BY <2>1, <2>3 DEF Affected
<1>5. ASSUME NEW s \in Source, UpdateSource(s) PROVE P'
  <2>1. invocable' = invocable /\ supdated \subseteq supdated'  BY <1>5 DEF UpdateSource
  <2>2. crevoked'=crevoked /\ csuperseded'=csuperseded /\ cdeprecated'=cdeprecated
        /\ drifted'=drifted /\ integrity'=integrity  BY <1>5 DEF UpdateSource, SetDL
  <2>3. Affected(f)'  BY <2>1, <2>2 DEF Affected
  <2> QED  BY <2>1, <2>3 DEF Affected
<1>6. ASSUME NEW u \in Unit, DriftUnit(u) PROVE P'
  <2>1. invocable' = invocable /\ drifted \subseteq drifted'  BY <1>6 DEF DriftUnit
  <2>2. crevoked'=crevoked /\ csuperseded'=csuperseded /\ cdeprecated'=cdeprecated
        /\ supdated'=supdated /\ integrity'=integrity  BY <1>6 DEF DriftUnit, SetDL
  <2>3. Affected(f)'  BY <2>1, <2>2 DEF Affected
  <2> QED  BY <2>1, <2>3 DEF Affected
<1>7. ASSUME NEW g \in Form, FailIntegrity(g) PROVE P'
  <2>1. invocable' = invocable  BY <1>7 DEF FailIntegrity
  <2>2. crevoked'=crevoked /\ csuperseded'=csuperseded /\ cdeprecated'=cdeprecated
        /\ supdated'=supdated /\ drifted'=drifted  BY <1>7 DEF FailIntegrity, SetDL
  <2>3. \A h \in Form : integrity[h] = "failed" => integrity'[h] = "failed"
    BY <1>7 DEF FailIntegrity, TypeOK
  <2>4. Affected(f)'  BY <2>1, <2>2, <2>3 DEF Affected
  <2> QED  BY <2>1, <2>4 DEF Affected
<1>8. ASSUME NEW g \in Form, Invalidate(g) PROVE P' \/ ~(invocable[f]')
  <2>1. CASE g = f  BY <1>8, <2>1 DEF Invalidate, TypeOK
  <2>2. CASE g # f
    <3>1. invocable'[f] = invocable[f]
      <4>1. invocable' = [invocable EXCEPT ![g]=FALSE]  BY <1>8 DEF Invalidate
      <4>2. invocable \in [Form -> BOOLEAN]  BY DEF TypeOK
      <4> QED  BY <4>1, <4>2, <2>2
    <3>2. crevoked'=crevoked /\ csuperseded'=csuperseded /\ cdeprecated'=cdeprecated
          /\ supdated'=supdated /\ drifted'=drifted /\ integrity'=integrity
      BY <1>8 DEF Invalidate
    <3>3. Affected(f)'  BY <3>2 DEF Affected
    <3> QED  BY <3>1, <3>3 DEF Affected
  <2> QED  BY <2>1, <2>2
<1>9. ASSUME NEW g \in Form, Recompile(g) PROVE P'
  \* Recompile requires ~Affected(g). If g=f, contradicts Affected(f). So g#f and
  \* invocable[f] unchanged; trigger-sets unchanged so Affected(f) preserved.
  <2>1. ~Affected(g)  BY <1>9 DEF Recompile
  <2>2. g # f  BY <2>1
  <2>3. invocable'[f] = invocable[f]
    <3>1. invocable' = [invocable EXCEPT ![g]=TRUE]  BY <1>9 DEF Recompile
    <3>2. invocable \in [Form -> BOOLEAN]  BY DEF TypeOK
    <3> QED  BY <3>1, <3>2, <2>2
  <2>4. crevoked'=crevoked /\ csuperseded'=csuperseded /\ cdeprecated'=cdeprecated
        /\ supdated'=supdated /\ drifted'=drifted /\ integrity'=integrity
    BY <1>9 DEF Recompile
  <2>5. Affected(f)'  BY <2>4 DEF Affected
  <2> QED  BY <2>3, <2>5 DEF Affected
<1>10. ASSUME NEW g \in Form, InvokeStrict(g) PROVE P'
  BY <1>10 DEF InvokeStrict, Affected, vars
<1>11. CASE Tick
  <2>1. invocable'=invocable /\ crevoked'=crevoked /\ csuperseded'=csuperseded
        /\ cdeprecated'=cdeprecated /\ supdated'=supdated /\ drifted'=drifted
        /\ integrity'=integrity  BY <1>11 DEF Tick
  <2>2. Affected(f)'  BY <2>1 DEF Affected
  <2> QED  BY <2>1, <2>2 DEF Affected
<1> QED
  BY <1>1,<1>2,<1>3,<1>4,<1>5,<1>6,<1>7,<1>8,<1>9,<1>10,<1>11 DEF Next


\* ===========================================================================
\* BOUNDED RESPONSE over all six triggers, as a single leads-to whose target
\* carries the bound. For every form affected by ANY of the six triggers:
\* it becomes non-invocable by governance-clock time deadline[f] = triggerTime+Delta.
\* This is the uniform invalidation surface's central promise, certified.
\* ===========================================================================
BoundedResponse ==
    \A f \in Form : (Affected(f) /\ invocable[f]) ~> (~invocable[f] /\ now <= deadline[f])

THEOREM LiveB == SpecL => BoundedResponse
<1> USE DeltaAsm, ChainAsm, UnitOfAsm, ParentAsm, RootsType, RootsClosure

<1>1. ASSUME NEW f \in Form
      PROVE  SpecL => ((Affected(f) /\ invocable[f]) ~> (~invocable[f] /\ now <= deadline[f]))
  <2> DEFINE P == Affected(f) /\ invocable[f]
  <2> DEFINE Q == ~invocable[f] /\ now <= deadline[f]
  <2>1. (TypeOK /\ NoOvershoot /\ P /\ [Next]_vars) => (P' \/ Q')
    <3> SUFFICES ASSUME TypeOK, NoOvershoot, P, [Next]_vars, ~(P') PROVE Q'
      OBVIOUS
    <3>1. (Affected(f) /\ invocable[f])' \/ ~(invocable[f]')
      BY StepLeadsto
    <3>2. ~invocable[f]'  BY <3>1
    <3>3. now <= deadline[f]  BY NoOvershoot DEF NoOvershoot
    <3>4. now' = now /\ deadline'[f] = deadline[f]
      <4>1. CASE UNCHANGED vars  BY <4>1 DEF vars
      <4>2. ASSUME NEW c \in Cred, RevokeCred(c) PROVE now'=now /\ deadline'[f]=deadline[f]
        BY <4>2, <3>2 DEF RevokeCred, SetDL
      <4>3. ASSUME NEW c \in Cred, SupersedeCred(c) PROVE now'=now /\ deadline'[f]=deadline[f]
        BY <4>3, <3>2 DEF SupersedeCred, SetDL
      <4>4. ASSUME NEW x \in (Cred \cup Unit), Deprecate(x) PROVE now'=now /\ deadline'[f]=deadline[f]
        BY <4>4, <3>2 DEF Deprecate, SetDL
      <4>5. ASSUME NEW s \in Source, UpdateSource(s) PROVE now'=now /\ deadline'[f]=deadline[f]
        BY <4>5, <3>2 DEF UpdateSource, SetDL
      <4>6. ASSUME NEW u \in Unit, DriftUnit(u) PROVE now'=now /\ deadline'[f]=deadline[f]
        BY <4>6, <3>2 DEF DriftUnit, SetDL
      <4>7. ASSUME NEW g \in Form, FailIntegrity(g) PROVE now'=now /\ deadline'[f]=deadline[f]
        BY <4>7, <3>2 DEF FailIntegrity, SetDL
      <4>8. ASSUME NEW g \in Form, Invalidate(g) PROVE now'=now /\ deadline'[f]=deadline[f]
        BY <4>8 DEF Invalidate
      <4>9. ASSUME NEW g \in Form, Recompile(g) PROVE now'=now /\ deadline'[f]=deadline[f]
        BY <4>9 DEF Recompile
      <4>10. ASSUME NEW g \in Form, InvokeStrict(g) PROVE now'=now /\ deadline'[f]=deadline[f]
        BY <4>10, <3>2 DEF InvokeStrict, vars
      <4>11. CASE Tick  BY <4>11, <3>2 DEF Tick
      <4> QED
        BY <4>1,<4>2,<4>3,<4>4,<4>5,<4>6,<4>7,<4>8,<4>9,<4>10,<4>11 DEF Next
    <3>5. now' <= deadline'[f]  BY <3>3, <3>4
    <3> QED  BY <3>2, <3>5 DEF Q
  <2>2. (TypeOK /\ NoOvershoot /\ P /\ <<Next /\ Invalidate(f)>>_vars) => Q'
    <3> SUFFICES ASSUME TypeOK, NoOvershoot, P, Invalidate(f) PROVE Q'
      BY DEF vars
    <3>1. invocable' = [invocable EXCEPT ![f]=FALSE]  BY DEF Invalidate
    <3>2. invocable \in [Form -> BOOLEAN]  BY DEF TypeOK
    <3>3. ~invocable[f]'  BY <3>1, <3>2
    <3>4. now <= deadline[f]  BY NoOvershoot DEF NoOvershoot
    <3>5. now' = now /\ deadline'[f] = deadline[f]  BY DEF Invalidate
    <3> QED  BY <3>3, <3>4, <3>5 DEF Q
  <2>3. (TypeOK /\ P) => ENABLED <<Invalidate(f)>>_vars
    BY EnabledInval
  <2>4. SpecL => [][Next]_vars  BY DEF SpecL
  <2>5. SpecL => WFInv(f)
    <3>1. SpecL => Fairness  BY PTL DEF SpecL
    <3>2. Fairness => WFInv(f)  BY DEF Fairness
    <3> QED  BY <3>1, <3>2
  <2>6. SpecL => []TypeOK  BY TypeCorrect
  <2>7. SpecL => []NoOvershoot  BY BoundedLatency, PTL DEF SpecL, Spec
  <2> QED
    BY <2>1, <2>2, <2>3, <2>4, <2>5, <2>6, <2>7, PTL DEF WFInv
<1>2. QED  BY <1>1 DEF BoundedResponse

====
