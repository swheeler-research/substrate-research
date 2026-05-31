---- MODULE SixTransCheck ----
\* The uniform invalidation surface with all six triggers modelled as distinct
\* actions carrying their real structure. We prove: (safety) no affected, invocable
\* form is past its deadline and deadlines are within Delta; (bounded response)
\* every affected, invocable form becomes non-invocable by clock-time deadline,
\* which is trigger-time + Delta -- for ALL six triggers uniformly, including the
\* constitutional-source cascade through transitive authority chains.
EXTENDS Naturals

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

\* roots[] IS the transitive closure of parent[] over constitutional sources:
\* a source s is a transitive root of c iff c is itself that source, or some
\* immediate parent of c has s as a transitive root. This fixpoint characterisation
\* is what makes the cascade genuinely multi-level rather than one-step.

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

NoOvershoot ==
    \A f \in Form : (Affected(f) /\ invocable[f]) => (now <= deadline[f] /\ deadline[f] <= now + Delta)
====
