---- MODULE InvLive3 ----
EXTENDS Naturals, TLAPS
CONSTANTS Cred, Unit, Form, Delta, chain, unitOf
VARIABLES cstatus, ustatus, csrc, witness, invocable, now, deadline, hasDL
NoneDL == 0
Affected(f) ==
    \/ \E c \in chain[f] : cstatus[c] \in {"revoked","superseded","deprecated"}
    \/ ustatus[unitOf[f]] = "deprecated"
    \/ \E c \in chain[f] : c \in csrc
    \/ witness[f] = "failed"
TypeOK ==
    /\ cstatus \in [Cred -> {"valid","revoked","superseded","deprecated"}]
    /\ ustatus \in [Unit -> {"active","deprecated"}]
    /\ csrc \in SUBSET Cred
    /\ witness \in [Form -> {"ok","failed"}]
    /\ invocable \in [Form -> BOOLEAN]
    /\ now \in Nat /\ deadline \in [Form -> Nat] /\ hasDL \in [Form -> BOOLEAN]
Init ==
    /\ cstatus = [c \in Cred |-> "valid"] /\ ustatus = [u \in Unit |-> "active"]
    /\ csrc = {} /\ witness = [f \in Form |-> "ok"] /\ invocable = [f \in Form |-> TRUE]
    /\ now = 0 /\ deadline = [f \in Form |-> NoneDL] /\ hasDL = [f \in Form |-> FALSE]
SetDL(na) ==
    /\ deadline' = [f \in Form |-> IF f \in na /\ ~hasDL[f] THEN now + Delta ELSE deadline[f]]
    /\ hasDL' = [f \in Form |-> hasDL[f] \/ (f \in na)]
RevokeCred(c) == /\ cstatus[c] = "valid" /\ cstatus' = [cstatus EXCEPT ![c] = "revoked"]
    /\ SetDL({f \in Form : c \in chain[f]}) /\ UNCHANGED <<ustatus, csrc, witness, invocable, now>>
DeprecateUnit(u) == /\ ustatus[u] = "active" /\ ustatus' = [ustatus EXCEPT ![u] = "deprecated"]
    /\ SetDL({f \in Form : unitOf[f] = u}) /\ UNCHANGED <<cstatus, csrc, witness, invocable, now>>
UpdateSource(c) == /\ c \notin csrc /\ csrc' = csrc \cup {c}
    /\ SetDL({f \in Form : c \in chain[f]}) /\ UNCHANGED <<cstatus, ustatus, witness, invocable, now>>
FailIntegrity(f) == /\ witness[f] = "ok" /\ witness' = [witness EXCEPT ![f] = "failed"]
    /\ SetDL({f}) /\ UNCHANGED <<cstatus, ustatus, csrc, invocable, now>>
Invalidate(f) == /\ Affected(f) /\ invocable[f] = TRUE
    /\ invocable' = [invocable EXCEPT ![f] = FALSE] /\ hasDL' = [hasDL EXCEPT ![f] = FALSE]
    /\ deadline' = deadline /\ UNCHANGED <<cstatus, ustatus, csrc, witness, now>>
Recompile(f) == /\ invocable[f] = FALSE /\ ~Affected(f)
    /\ invocable' = [invocable EXCEPT ![f] = TRUE] /\ hasDL' = [hasDL EXCEPT ![f] = FALSE]
    /\ deadline' = deadline /\ UNCHANGED <<cstatus, ustatus, csrc, witness, now>>
InvokeStrict(f) == /\ invocable[f] = TRUE /\ ~Affected(f)
    /\ UNCHANGED <<cstatus, ustatus, csrc, witness, invocable, now, deadline, hasDL>>
TickOK == \A f \in Form : ~(Affected(f) /\ invocable[f] /\ hasDL[f] /\ now >= deadline[f])
Tick == /\ TickOK /\ now' = now + 1
    /\ UNCHANGED <<cstatus, ustatus, csrc, witness, invocable, deadline, hasDL>>
Next == \/ \E c \in Cred : RevokeCred(c) \/ \E u \in Unit : DeprecateUnit(u)
    \/ \E c \in Cred : UpdateSource(c) \/ \E f \in Form : FailIntegrity(f)
    \/ \E f \in Form : Invalidate(f) \/ \E f \in Form : Recompile(f)
    \/ \E f \in Form : InvokeStrict(f) \/ Tick
vars == <<cstatus, ustatus, csrc, witness, invocable, now, deadline, hasDL>>
WFInv(ff) == WF_vars(Invalidate(ff))
Fairness == \A f \in Form : WFInv(f)
SpecL == Init /\ [][Next]_vars /\ Fairness
ASSUME DeltaAsm == Delta \in Nat /\ Delta >= 1
ASSUME ChainAsm == chain \in [Form -> SUBSET Cred]
ASSUME UnitOfAsm == unitOf \in [Form -> Unit]

\* Key non-temporal lemma: from P and a Next-step, either P persists or f is invalidated.
\* Proved with TypeOK in scope so EXCEPT applications have their domain facts.
LEMMA StepLeadsto ==
  ASSUME TypeOK, NEW f \in Form, Affected(f), invocable[f], [Next]_vars
  PROVE  (Affected(f) /\ invocable[f])' \/ (~invocable[f])'
<1> USE DeltaAsm, ChainAsm, UnitOfAsm
<1>1. CASE UNCHANGED vars   BY <1>1 DEF vars, Affected
<1>2. ASSUME NEW c \in Cred, RevokeCred(c) PROVE (Affected(f) /\ invocable[f])' \/ (~invocable[f])'
  <2>1. invocable' = invocable  BY <1>2 DEF RevokeCred
  <2>2. Affected(f)'
    <3>1. cstatus' = [cstatus EXCEPT ![c]="revoked"]  BY <1>2 DEF RevokeCred
    <3>2. ustatus'=ustatus /\ csrc'=csrc /\ witness'=witness  BY <1>2 DEF RevokeCred
    <3>3. ASSUME NEW d \in chain[f], cstatus[d] \in {"revoked","superseded","deprecated"}
          PROVE cstatus'[d] \in {"revoked","superseded","deprecated"}
      <4>1. d \in Cred  BY ChainAsm
      <4>2. c \in Cred  OBVIOUS
      <4>3. cstatus \in [Cred -> {"valid","revoked","superseded","deprecated"}]  BY DEF TypeOK
      <4>4. cstatus'[d] = (IF d = c THEN "revoked" ELSE cstatus[d])  BY <3>1, <4>1, <4>2, <4>3
      <4>5. CASE d = c   BY <4>4, <4>5
      <4>6. CASE d # c   BY <4>4, <4>6, <3>3
      <4> QED  BY <4>5, <4>6
    <3> QED  BY <3>2, <3>3 DEF Affected
  <2> QED  BY <2>1, <2>2 DEF Affected
<1>3. ASSUME NEW u \in Unit, DeprecateUnit(u) PROVE (Affected(f) /\ invocable[f])' \/ (~invocable[f])'
  <2>1. invocable' = invocable  BY <1>3 DEF DeprecateUnit
  <2>2. Affected(f)'
    <3>1. ustatus' = [ustatus EXCEPT ![u]="deprecated"]  BY <1>3 DEF DeprecateUnit
    <3>2. cstatus'=cstatus /\ csrc'=csrc /\ witness'=witness  BY <1>3 DEF DeprecateUnit
    <3>3. ustatus[unitOf[f]]="deprecated" => ustatus'[unitOf[f]]="deprecated"
      <4>1. unitOf[f] \in Unit  BY UnitOfAsm
      <4>2. u \in Unit  OBVIOUS
      <4>3. ustatus \in [Unit -> {"active","deprecated"}]  BY DEF TypeOK
      <4>4. ustatus'[unitOf[f]] = (IF unitOf[f] = u THEN "deprecated" ELSE ustatus[unitOf[f]])  BY <3>1, <4>1, <4>2, <4>3
      <4> QED  BY <4>4
    <3> QED  BY <3>2, <3>3 DEF Affected
  <2> QED  BY <2>1, <2>2 DEF Affected
<1>4. ASSUME NEW c \in Cred, UpdateSource(c) PROVE (Affected(f) /\ invocable[f])' \/ (~invocable[f])'
  <2>1. invocable' = invocable  BY <1>4 DEF UpdateSource
  <2>2. Affected(f)'
    <3>1. csrc' = csrc \cup {c}  BY <1>4 DEF UpdateSource
    <3>2. cstatus'=cstatus /\ ustatus'=ustatus /\ witness'=witness  BY <1>4 DEF UpdateSource
    <3>3. ASSUME NEW d \in chain[f], d \in csrc PROVE d \in csrc'
      BY <3>1, <3>3
    <3> QED  BY <3>2, <3>3 DEF Affected
  <2> QED  BY <2>1, <2>2 DEF Affected
<1>5. ASSUME NEW g \in Form, FailIntegrity(g) PROVE (Affected(f) /\ invocable[f])' \/ (~invocable[f])'
  <2>1. invocable' = invocable  BY <1>5 DEF FailIntegrity
  <2>2. Affected(f)'
    <3>1. witness' = [witness EXCEPT ![g]="failed"]  BY <1>5 DEF FailIntegrity
    <3>2. cstatus'=cstatus /\ ustatus'=ustatus /\ csrc'=csrc  BY <1>5 DEF FailIntegrity
    <3>3. witness[f]="failed" => witness'[f]="failed"
      <4>1. witness \in [Form -> {"ok","failed"}]  BY DEF TypeOK
      <4>2. witness'[f] = (IF f = g THEN "failed" ELSE witness[f])  BY <3>1, <4>1
      <4> QED  BY <4>2
    <3> QED  BY <3>2, <3>3 DEF Affected
  <2> QED  BY <2>1, <2>2 DEF Affected
<1>6. ASSUME NEW g \in Form, Invalidate(g) PROVE (Affected(f) /\ invocable[f])' \/ (~invocable[f])'
  <2>1. CASE g = f
    <3>1. invocable' = [invocable EXCEPT ![g]=FALSE]  BY <1>6 DEF Invalidate
    <3>2. invocable \in [Form -> BOOLEAN]  BY DEF TypeOK
    <3>3. invocable'[f] = FALSE  BY <3>1, <3>2, <2>1
    <3> QED  BY <3>3
  <2>2. CASE g # f
    <3>1. invocable' = [invocable EXCEPT ![g]=FALSE]  BY <1>6 DEF Invalidate
    <3>2. invocable'[f] = invocable[f]
      <4>1. invocable \in [Form -> BOOLEAN]  BY DEF TypeOK
      <4>2. g \in Form  OBVIOUS
      <4> QED  BY <3>1, <2>2, <4>1, <4>2
    <3>3. cstatus'=cstatus /\ ustatus'=ustatus /\ csrc'=csrc /\ witness'=witness  BY <1>6 DEF Invalidate
    <3> QED  BY <3>2, <3>3 DEF Affected
  <2> QED  BY <2>1, <2>2
<1>7. ASSUME NEW g \in Form, Recompile(g) PROVE (Affected(f) /\ invocable[f])' \/ (~invocable[f])'
  <2>1. ~Affected(g)  BY <1>7 DEF Recompile
  <2>2. cstatus'=cstatus /\ ustatus'=ustatus /\ csrc'=csrc /\ witness'=witness  BY <1>7 DEF Recompile
  <2>3. Affected(f)'  BY <2>2 DEF Affected
  <2>4. invocable' = [invocable EXCEPT ![g]=TRUE]  BY <1>7 DEF Recompile
  <2>5. invocable \in [Form -> BOOLEAN]  BY DEF TypeOK
  <2>6. CASE g = f
    \* recompiling g=f makes f invocable and ~Affected(f); but we ASSUMED Affected(f),
    \* and Recompile(g) requires ~Affected(g)=~Affected(f), contradiction.
    BY <1>7, <2>6 DEF Recompile
  <2>7. CASE g # f
    <3>1. invocable'[f] = invocable[f]  BY <2>4, <2>5, <2>7
    <3> QED  BY <2>3, <3>1 DEF Affected
  <2> QED  BY <2>6, <2>7
<1>8. ASSUME NEW g \in Form, InvokeStrict(g) PROVE (Affected(f) /\ invocable[f])' \/ (~invocable[f])'
  BY <1>8 DEF InvokeStrict, Affected
<1>9. CASE Tick  BY <1>9 DEF Tick, Affected
<1> QED  BY <1>1,<1>2,<1>3,<1>4,<1>5,<1>6,<1>7,<1>8,<1>9 DEF Next, vars

LEMMA EnabledInval ==
  ASSUME TypeOK, NEW f \in Form, Affected(f), invocable[f]
  PROVE  ENABLED <<Invalidate(f)>>_vars
<1> USE DeltaAsm
<1> QED  BY ExpandENABLED DEF Invalidate, vars, TypeOK

LEMMA TypeCorrect == SpecL => []TypeOK
<1> USE DeltaAsm, ChainAsm, UnitOfAsm
<1>1. Init => TypeOK
  <2> SUFFICES ASSUME Init PROVE TypeOK  OBVIOUS
  <2>1. cstatus \in [Cred -> {"valid","revoked","superseded","deprecated"}]  BY DEF Init
  <2>2. ustatus \in [Unit -> {"active","deprecated"}]  BY DEF Init
  <2>3. csrc \in SUBSET Cred  BY DEF Init
  <2>4. witness \in [Form -> {"ok","failed"}]  BY DEF Init
  <2>5. invocable \in [Form -> BOOLEAN]  BY DEF Init
  <2>6. now \in Nat /\ deadline \in [Form -> Nat] /\ hasDL \in [Form -> BOOLEAN]  BY DEF Init, NoneDL
  <2> QED  BY <2>1,<2>2,<2>3,<2>4,<2>5,<2>6 DEF TypeOK
<1>2. TypeOK /\ [Next]_vars => TypeOK'
  BY DEF TypeOK, Next, vars, RevokeCred, DeprecateUnit, UpdateSource,
         FailIntegrity, Invalidate, Recompile, InvokeStrict, Tick, SetDL
<1> QED  BY <1>1, <1>2, PTL DEF SpecL

BoundInv ==
    /\ TypeOK
    /\ \A f \in Form : (Affected(f) /\ invocable[f]) => (hasDL[f] /\ now <= deadline[f])
    /\ \A f \in Form : (hasDL[f] /\ invocable[f]) => Affected(f)
    /\ \A f \in Form : (hasDL[f] /\ invocable[f]) => now <= deadline[f]
    /\ \A f \in Form : (hasDL[f] /\ invocable[f]) => deadline[f] <= now + Delta

NoOvershoot ==
    \A f \in Form :
        (Affected(f) /\ invocable[f]) => (now <= deadline[f] /\ deadline[f] <= now + Delta)

\* Bound invariant holds under SpecL (fairness does not affect the [Next]_vars argument).
LEMMA BoundHolds == SpecL => []BoundInv
<1> USE DeltaAsm, ChainAsm, UnitOfAsm
<1>1. Init => BoundInv
  BY DEF Init, BoundInv, TypeOK, Affected, NoneDL
<1>2. BoundInv /\ [Next]_vars => BoundInv'
  <2> SUFFICES ASSUME BoundInv, [Next]_vars PROVE BoundInv'  OBVIOUS
  <2>1. CASE UNCHANGED vars  BY <2>1 DEF BoundInv, TypeOK, Affected, vars
  <2>2. ASSUME NEW c \in Cred, RevokeCred(c) PROVE BoundInv'
    BY <2>2 DEF BoundInv, TypeOK, Affected, RevokeCred, SetDL
  <2>3. ASSUME NEW u \in Unit, DeprecateUnit(u) PROVE BoundInv'
    BY <2>3 DEF BoundInv, TypeOK, Affected, DeprecateUnit, SetDL
  <2>4. ASSUME NEW c \in Cred, UpdateSource(c) PROVE BoundInv'
    BY <2>4 DEF BoundInv, TypeOK, Affected, UpdateSource, SetDL
  <2>5. ASSUME NEW f \in Form, FailIntegrity(f) PROVE BoundInv'
    BY <2>5 DEF BoundInv, TypeOK, Affected, FailIntegrity, SetDL
  <2>6. ASSUME NEW f \in Form, Invalidate(f) PROVE BoundInv'
    BY <2>6 DEF BoundInv, TypeOK, Affected, Invalidate
  <2>7. ASSUME NEW f \in Form, Recompile(f) PROVE BoundInv'
    BY <2>7 DEF BoundInv, TypeOK, Affected, Recompile
  <2>8. ASSUME NEW f \in Form, InvokeStrict(f) PROVE BoundInv'
    BY <2>8 DEF BoundInv, TypeOK, Affected, InvokeStrict
  <2>9. CASE Tick  BY <2>9 DEF BoundInv, TypeOK, Affected, Tick, TickOK
  <2>10. QED  BY <2>1,<2>2,<2>3,<2>4,<2>5,<2>6,<2>7,<2>8,<2>9 DEF Next, vars
<1>3. QED  BY <1>1, <1>2, PTL DEF SpecL

THEOREM BoundedLatency == SpecL => []NoOvershoot
<1>1. BoundInv => NoOvershoot  BY DEF BoundInv, NoOvershoot
<1>2. QED  BY <1>1, BoundHolds, PTL DEF NoOvershoot

Liveness == \A f \in Form : (Affected(f) /\ invocable[f]) ~> ~invocable[f]

THEOREM Live == SpecL => Liveness
<1> USE DeltaAsm, ChainAsm, UnitOfAsm
<1>1. ASSUME NEW f \in Form
      PROVE  SpecL => ((Affected(f) /\ invocable[f]) ~> ~invocable[f])
  <2> DEFINE P == Affected(f) /\ invocable[f]
  <2> DEFINE Q == ~invocable[f]
  <2>1. (TypeOK /\ P /\ [Next]_vars) => (P' \/ Q')
    BY StepLeadsto DEF P, Q
  <2>2. (TypeOK /\ P /\ <<Next /\ Invalidate(f)>>_vars) => Q'
    <3> SUFFICES ASSUME TypeOK, P, Invalidate(f) PROVE Q'
      BY DEF vars
    <3>1. invocable' = [invocable EXCEPT ![f]=FALSE]  BY DEF Invalidate
    <3>2. invocable \in [Form -> BOOLEAN]  BY DEF TypeOK
    <3>3. invocable'[f] = FALSE  BY <3>1, <3>2
    <3> QED  BY <3>3 DEF Q
  <2>3. (TypeOK /\ P) => ENABLED <<Invalidate(f)>>_vars
    BY EnabledInval DEF P
  <2>4. SpecL => [][Next]_vars  BY DEF SpecL
  <2>5. SpecL => WFInv(f)
    <3>1. SpecL => Fairness  BY PTL DEF SpecL
    <3>2. Fairness => WFInv(f)  BY DEF Fairness
    <3> QED  BY <3>1, <3>2
  <2>6. SpecL => []TypeOK  BY TypeCorrect
  <2> QED
    BY <2>1, <2>2, <2>3, <2>4, <2>5, <2>6, PTL DEF WFInv
<1>2. QED  BY <1>1 DEF Liveness

\* ===========================================================================
\* COMPOSED RESULT (the architecture's actual claim, with its dependency explicit)
\* Under weak fairness on invalidation (SpecL):
\*   (progress) every affected, invocable form eventually becomes non-invocable; AND
\*   (bound)    at all times, a stale invocable form's deadline is within Delta of
\*              the governance clock and the clock has not passed it.
\* The conjunction is the bounded-latency guarantee: invalidation occurs, and the
\* governance clock cannot advance more than Delta past the trigger before it does.
\* The bound is unconditional ([]NoOvershoot needs no fairness); the progress
\* conjunct is what requires fairness. Stating them together makes the
\* fairness dependency explicit and the composition a single proved object.
\* ===========================================================================
BoundedEnforcement == Liveness /\ []NoOvershoot

THEOREM BoundedEnforcementThm == SpecL => BoundedEnforcement
<1>1. SpecL => Liveness  BY Live
<1>2. SpecL => []NoOvershoot  BY BoundedLatency
<1> QED  BY <1>1, <1>2 DEF BoundedEnforcement


\* ===========================================================================
\* BOUNDED-RESPONSE THEOREM, stated as a single clock-bounded leads-to whose
\* TARGET literally contains the latency bound. Since deadline[f] is fixed at
\* (triggerTime + Delta) when the form becomes affected, the statement
\*   (Affected(f) /\ invocable[f]) ~> (~invocable[f] /\ now <= deadline[f])
\* says: a stale, invocable form becomes non-invocable no later than clock-time
\* deadline[f] = triggerTime + Delta. This is bounded-latency enforcement as one
\* theorem, not a conjunction left to interpretation.
\* ===========================================================================
BoundedResponse ==
    \A f \in Form : (Affected(f) /\ invocable[f]) ~> (~invocable[f] /\ now <= deadline[f])

THEOREM LiveB == SpecL => BoundedResponse
<1> USE DeltaAsm, ChainAsm, UnitOfAsm
<1>1. ASSUME NEW f \in Form
      PROVE  SpecL => ((Affected(f) /\ invocable[f]) ~> (~invocable[f] /\ now <= deadline[f]))
  <2> DEFINE P == Affected(f) /\ invocable[f]
  <2> DEFINE Q == ~invocable[f] /\ now <= deadline[f]
  \* Premise 1: with TypeOK and NoOvershoot in scope, a step from P either keeps P
  \* or reaches Q (the only exit from P is Invalidate(f), which gives Q).
  <2>1. (TypeOK /\ NoOvershoot /\ P /\ [Next]_vars) => (P' \/ Q')
    <3> SUFFICES ASSUME TypeOK, NoOvershoot, P, [Next]_vars, ~(P') PROVE Q'
      OBVIOUS
    \* From StepLeadsto, P' \/ ~invocable[f]'. Since ~P', we have ~invocable[f]'.
    <3>1. (TypeOK /\ P /\ [Next]_vars) => (P' \/ ~invocable[f]')
      BY StepLeadsto DEF P
    <3>2. ~invocable[f]'  BY <3>1
    \* Now show now' <= deadline'[f]. The transition reaching ~invocable[f]' from
    \* invocable[f] is Invalidate(f); it preserves now and deadline. NoOvershoot
    \* pre-state gives now <= deadline[f].
    <3>3. now <= deadline[f]  BY NoOvershoot DEF NoOvershoot, P
    \* Identify the action: invocable[f] true, invocable[f]' false.
    <3>4. now' = now /\ deadline'[f] = deadline[f]
      <4>1. CASE UNCHANGED vars  BY <4>1 DEF vars, P
      <4>2. ASSUME NEW c \in Cred, RevokeCred(c) PROVE now' = now /\ deadline'[f] = deadline[f]
        \* RevokeCred keeps invocable unchanged, contradicting ~invocable[f]'
        BY <4>2, <3>2 DEF RevokeCred, P
      <4>3. ASSUME NEW u \in Unit, DeprecateUnit(u) PROVE now' = now /\ deadline'[f] = deadline[f]
        BY <4>3, <3>2 DEF DeprecateUnit, P
      <4>4. ASSUME NEW c \in Cred, UpdateSource(c) PROVE now' = now /\ deadline'[f] = deadline[f]
        BY <4>4, <3>2 DEF UpdateSource, P
      <4>5. ASSUME NEW g \in Form, FailIntegrity(g) PROVE now' = now /\ deadline'[f] = deadline[f]
        BY <4>5, <3>2 DEF FailIntegrity, P
      <4>6. ASSUME NEW g \in Form, Invalidate(g) PROVE now' = now /\ deadline'[f] = deadline[f]
        BY <4>6 DEF Invalidate
      <4>7. ASSUME NEW g \in Form, Recompile(g) PROVE now' = now /\ deadline'[f] = deadline[f]
        BY <4>7 DEF Recompile
      <4>8. ASSUME NEW g \in Form, InvokeStrict(g) PROVE now' = now /\ deadline'[f] = deadline[f]
        BY <4>8, <3>2 DEF InvokeStrict, P
      <4>9. CASE Tick  BY <4>9, <3>2 DEF Tick, P
      <4> QED  BY <4>1,<4>2,<4>3,<4>4,<4>5,<4>6,<4>7,<4>8,<4>9 DEF Next, vars
    <3>5. now' <= deadline'[f]  BY <3>3, <3>4
    <3> QED  BY <3>2, <3>5 DEF Q
  \* Premise 2: an Invalidate(f) step from P reaches Q.
  <2>2. (TypeOK /\ NoOvershoot /\ P /\ <<Next /\ Invalidate(f)>>_vars) => Q'
    <3> SUFFICES ASSUME TypeOK, NoOvershoot, P, Invalidate(f) PROVE Q'
      BY DEF vars
    <3>1. invocable' = [invocable EXCEPT ![f]=FALSE]  BY DEF Invalidate
    <3>2. invocable \in [Form -> BOOLEAN]  BY DEF TypeOK
    <3>3. ~invocable[f]'  BY <3>1, <3>2
    <3>4. now <= deadline[f]  BY NoOvershoot DEF NoOvershoot, P
    <3>5. now' = now /\ deadline'[f] = deadline[f]  BY DEF Invalidate
    <3> QED  BY <3>3, <3>4, <3>5 DEF Q
  \* Premise 3: invalidation enabled.
  <2>3. (TypeOK /\ P) => ENABLED <<Invalidate(f)>>_vars
    BY EnabledInval DEF P
  <2>4. SpecL => [][Next]_vars  BY DEF SpecL
  <2>5. SpecL => WFInv(f)
    <3>1. SpecL => Fairness  BY PTL DEF SpecL
    <3>2. Fairness => WFInv(f)  BY DEF Fairness
    <3> QED  BY <3>1, <3>2
  <2>6. SpecL => []TypeOK  BY TypeCorrect
  <2>7. SpecL => []NoOvershoot  BY BoundedLatency
  <2> QED
    BY <2>1, <2>2, <2>3, <2>4, <2>5, <2>6, <2>7, PTL DEF WFInv
<1>2. QED  BY <1>1 DEF BoundedResponse

====
