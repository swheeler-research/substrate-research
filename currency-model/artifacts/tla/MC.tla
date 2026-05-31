------------------------------- MODULE MC -------------------------------
EXTENDS Naturals, FiniteSets
CONSTANTS Cred, Unit, Form, Delta, c0, c1, u0, f0, f1, NONE

chain == [f \in Form |-> IF f = f0 THEN {c0} ELSE {c0, c1}]
unitOf == [f \in Form |-> u0]

VARIABLES cstatus, ustatus, csrc, witness, invocable, now, deadline, lastInvokeClean
vars == <<cstatus, ustatus, csrc, witness, invocable, now, deadline, lastInvokeClean>>

Affected(f) ==
    \/ \E c \in chain[f] : cstatus[c] \in {"revoked","superseded","deprecated"}
    \/ ustatus[unitOf[f]] = "deprecated"
    \/ \E c \in chain[f] : c \in csrc
    \/ witness[f] = "failed"

Init ==
    /\ cstatus = [c \in Cred |-> "valid"]
    /\ ustatus = [u \in Unit |-> "active"]
    /\ csrc = {}
    /\ witness = [f \in Form |-> "ok"]
    /\ invocable = [f \in Form |-> TRUE]
    /\ now = 0
    /\ deadline = [f \in Form |-> NONE]
    /\ lastInvokeClean = TRUE

SetDL(na) == deadline' = [f \in Form |-> IF f \in na /\ deadline[f] = NONE THEN now + Delta ELSE deadline[f]]

RevokeCred(c) ==
    /\ cstatus[c] = "valid"
    /\ cstatus' = [cstatus EXCEPT ![c] = "revoked"]
    /\ SetDL({f \in Form : c \in chain[f]})
    /\ UNCHANGED <<ustatus, csrc, witness, invocable, now, lastInvokeClean>>

DeprecateUnit(u) ==
    /\ ustatus[u] = "active"
    /\ ustatus' = [ustatus EXCEPT ![u] = "deprecated"]
    /\ SetDL({f \in Form : unitOf[f] = u})
    /\ UNCHANGED <<cstatus, csrc, witness, invocable, now, lastInvokeClean>>

UpdateSource(c) ==
    /\ c \notin csrc
    /\ csrc' = csrc \cup {c}
    /\ SetDL({f \in Form : c \in chain[f]})
    /\ UNCHANGED <<cstatus, ustatus, witness, invocable, now, lastInvokeClean>>

FailIntegrity(f) ==
    /\ witness[f] = "ok"
    /\ witness' = [witness EXCEPT ![f] = "failed"]
    /\ SetDL({f})
    /\ UNCHANGED <<cstatus, ustatus, csrc, invocable, now, lastInvokeClean>>

Invalidate(f) ==
    /\ Affected(f)
    /\ invocable[f] = TRUE
    /\ invocable' = [invocable EXCEPT ![f] = FALSE]
    /\ deadline' = [deadline EXCEPT ![f] = NONE]
    /\ UNCHANGED <<cstatus, ustatus, csrc, witness, now, lastInvokeClean>>

Recompile(f) ==
    /\ invocable[f] = FALSE
    /\ ~Affected(f)
    /\ invocable' = [invocable EXCEPT ![f] = TRUE]
    /\ UNCHANGED <<cstatus, ustatus, csrc, witness, now, deadline, lastInvokeClean>>

InvokeStrict(f) ==
    /\ invocable[f] = TRUE
    /\ ~Affected(f)
    /\ lastInvokeClean' = (~Affected(f))   \* records cleanliness of this invoke
    /\ UNCHANGED <<cstatus, ustatus, csrc, witness, invocable, now, deadline>>

TickEnabled == \A f \in Form : ~(Affected(f) /\ invocable[f] /\ deadline[f] # NONE /\ now >= deadline[f])

Tick ==
    /\ TickEnabled
    /\ now < 3
    /\ now' = now + 1
    /\ UNCHANGED <<cstatus, ustatus, csrc, witness, invocable, deadline, lastInvokeClean>>

Next ==
    \/ \E c \in Cred : RevokeCred(c)
    \/ \E u \in Unit : DeprecateUnit(u)
    \/ \E c \in Cred : UpdateSource(c)
    \/ \E f \in Form : FailIntegrity(f)
    \/ \E f \in Form : Invalidate(f)
    \/ \E f \in Form : Recompile(f)
    \/ \E f \in Form : InvokeStrict(f)
    \/ Tick

Spec == Init /\ [][Next]_vars

Inv_bound == \A f \in Form : (Affected(f) /\ invocable[f]) => (deadline[f] # NONE /\ now <= deadline[f])
Inv_action == lastInvokeClean = TRUE
Naive == \A f \in Form : invocable[f] => ~Affected(f)
=========================================================================
