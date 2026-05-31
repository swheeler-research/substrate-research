---- MODULE InvSurface ----
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
    /\ now \in Nat
    /\ deadline \in [Form -> Nat]
    /\ hasDL \in [Form -> BOOLEAN]

\* Safety invariant plus inductive support.
Inv ==
    /\ TypeOK
    /\ \A f \in Form : (Affected(f) /\ invocable[f]) => (hasDL[f] /\ now <= deadline[f])
    /\ \A f \in Form : (hasDL[f] /\ invocable[f]) => Affected(f)
    /\ \A f \in Form : (hasDL[f] /\ invocable[f]) => now <= deadline[f]

Init ==
    /\ cstatus = [c \in Cred |-> "valid"]
    /\ ustatus = [u \in Unit |-> "active"]
    /\ csrc = {}
    /\ witness = [f \in Form |-> "ok"]
    /\ invocable = [f \in Form |-> TRUE]
    /\ now = 0
    /\ deadline = [f \in Form |-> NoneDL]
    /\ hasDL = [f \in Form |-> FALSE]

SetDL(na) ==
    /\ deadline' = [f \in Form |-> IF f \in na /\ ~hasDL[f] THEN now + Delta ELSE deadline[f]]
    /\ hasDL' = [f \in Form |-> hasDL[f] \/ (f \in na)]

RevokeCred(c) ==
    /\ cstatus[c] = "valid"
    /\ cstatus' = [cstatus EXCEPT ![c] = "revoked"]
    /\ SetDL({f \in Form : c \in chain[f]})
    /\ UNCHANGED <<ustatus, csrc, witness, invocable, now>>

DeprecateUnit(u) ==
    /\ ustatus[u] = "active"
    /\ ustatus' = [ustatus EXCEPT ![u] = "deprecated"]
    /\ SetDL({f \in Form : unitOf[f] = u})
    /\ UNCHANGED <<cstatus, csrc, witness, invocable, now>>

UpdateSource(c) ==
    /\ c \notin csrc
    /\ csrc' = csrc \cup {c}
    /\ SetDL({f \in Form : c \in chain[f]})
    /\ UNCHANGED <<cstatus, ustatus, witness, invocable, now>>

FailIntegrity(f) ==
    /\ witness[f] = "ok"
    /\ witness' = [witness EXCEPT ![f] = "failed"]
    /\ SetDL({f})
    /\ UNCHANGED <<cstatus, ustatus, csrc, invocable, now>>

Invalidate(f) ==
    /\ Affected(f)
    /\ invocable[f] = TRUE
    /\ invocable' = [invocable EXCEPT ![f] = FALSE]
    /\ hasDL' = [hasDL EXCEPT ![f] = FALSE]
    /\ deadline' = deadline
    /\ UNCHANGED <<cstatus, ustatus, csrc, witness, now>>

Recompile(f) ==
    /\ invocable[f] = FALSE
    /\ ~Affected(f)
    /\ invocable' = [invocable EXCEPT ![f] = TRUE]
    /\ hasDL' = [hasDL EXCEPT ![f] = FALSE]
    /\ deadline' = deadline
    /\ UNCHANGED <<cstatus, ustatus, csrc, witness, now>>

InvokeStrict(f) ==
    /\ invocable[f] = TRUE
    /\ ~Affected(f)
    /\ UNCHANGED <<cstatus, ustatus, csrc, witness, invocable, now, deadline, hasDL>>

TickOK == \A f \in Form : ~(Affected(f) /\ invocable[f] /\ hasDL[f] /\ now >= deadline[f])
Tick ==
    /\ TickOK
    /\ now' = now + 1
    /\ UNCHANGED <<cstatus, ustatus, csrc, witness, invocable, deadline, hasDL>>

Next ==
    \/ \E c \in Cred : RevokeCred(c)
    \/ \E u \in Unit : DeprecateUnit(u)
    \/ \E c \in Cred : UpdateSource(c)
    \/ \E f \in Form : FailIntegrity(f)
    \/ \E f \in Form : Invalidate(f)
    \/ \E f \in Form : Recompile(f)
    \/ \E f \in Form : InvokeStrict(f)
    \/ Tick

vars == <<cstatus, ustatus, csrc, witness, invocable, now, deadline, hasDL>>
Spec == Init /\ [][Next]_vars

ASSUME DeltaAsm == Delta \in Nat /\ Delta >= 1
ASSUME ChainAsm == chain \in [Form -> SUBSET Cred]
ASSUME UnitOfAsm == unitOf \in [Form -> Unit]

THEOREM InitInv == Init => Inv
  BY DeltaAsm, ChainAsm, UnitOfAsm DEF Init, Inv, TypeOK, Affected, NoneDL

LEMMA StepInv == Inv /\ [Next]_vars => Inv'
<1> SUFFICES ASSUME Inv, [Next]_vars
             PROVE  Inv'
  OBVIOUS
<1>1. CASE \E c \in Cred : RevokeCred(c)
  BY <1>1, DeltaAsm, ChainAsm, UnitOfAsm DEF Inv, TypeOK, Affected, RevokeCred, SetDL, NoneDL
<1>2. CASE \E u \in Unit : DeprecateUnit(u)
  BY <1>2, DeltaAsm, ChainAsm, UnitOfAsm DEF Inv, TypeOK, Affected, DeprecateUnit, SetDL, NoneDL
<1>3. CASE \E c \in Cred : UpdateSource(c)
  BY <1>3, DeltaAsm, ChainAsm, UnitOfAsm DEF Inv, TypeOK, Affected, UpdateSource, SetDL, NoneDL
<1>4. CASE \E f \in Form : FailIntegrity(f)
  BY <1>4, DeltaAsm, ChainAsm, UnitOfAsm DEF Inv, TypeOK, Affected, FailIntegrity, SetDL, NoneDL
<1>5. CASE \E f \in Form : Invalidate(f)
  BY <1>5, DeltaAsm, ChainAsm, UnitOfAsm DEF Inv, TypeOK, Affected, Invalidate, NoneDL
<1>6. CASE \E f \in Form : Recompile(f)
  BY <1>6, DeltaAsm, ChainAsm, UnitOfAsm DEF Inv, TypeOK, Affected, Recompile, NoneDL
<1>7. CASE \E f \in Form : InvokeStrict(f)
  BY <1>7, DeltaAsm, ChainAsm, UnitOfAsm DEF Inv, TypeOK, Affected, InvokeStrict, NoneDL
<1>8. CASE Tick
  BY <1>8, DeltaAsm, ChainAsm, UnitOfAsm DEF Inv, TypeOK, Affected, Tick, TickOK, NoneDL
<1>9. CASE UNCHANGED vars
  BY <1>9 DEF Inv, TypeOK, Affected, vars, NoneDL
<1>10. QED
  BY <1>1, <1>2, <1>3, <1>4, <1>5, <1>6, <1>7, <1>8, <1>9 DEF Next

\* ---- Temporal: lift the inductive invariant to []Inv ----
THEOREM Safety == Spec => []Inv
<1>1. Init => Inv  BY InitInv
<1>2. Inv /\ [Next]_vars => Inv'  BY StepInv
<1>3. QED  BY <1>1, <1>2, PTL DEF Spec

====
