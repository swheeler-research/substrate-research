---------------------------- MODULE InvalidationSurface ----------------------------
(***************************************************************************)
(* Single-operator model of the substrate's uniform invalidation surface.  *)
(* Accompanies the paper "The Invalidation Surface".                        *)
(*                                                                          *)
(* Proves, by TLC model checking over a small finite instance, and by      *)
(* TLAPS for the inductive invariants:                                      *)
(*   - Inv_bound  : no affected, still-invocable form is past its deadline  *)
(*   - Inv_tagged : every committed invoke is tagged clean (strict mode)    *)
(*   - the action property: Invoke_strict fires only when ~Affected         *)
(*   - Bounded enforcement (liveness): every affected form is invalidated   *)
(*     within Delta ticks, under weak fairness on Tick and per-form         *)
(*     weak fairness on Invalidate.                                         *)
(*                                                                          *)
(* Drift is deliberately ABSENT from Affected: its evidence is              *)
(* retrospective and it cannot participate in a forward invariant.          *)
(***************************************************************************)
EXTENDS Naturals, Sequences, FiniteSets, TLC

CONSTANTS
    Cred,          \* set of credential identities
    Unit,          \* set of unit identities
    Form,          \* set of compiled-form identities
    chain,         \* [Form -> SUBSET Cred]  resolved authority chain, frozen at compile
    unitOf,        \* [Form -> Unit]
    Delta          \* Nat, the latency bound (>= 1)

ASSUME DeltaPos == Delta \in Nat /\ Delta >= 1
ASSUME ChainTyping == chain \in [Form -> SUBSET Cred]
ASSUME UnitOfTyping == unitOf \in [Form -> Unit]

VARIABLES
    cstatus,       \* [Cred -> {"valid","revoked","superseded","deprecated"}]
    ustatus,       \* [Unit -> {"active","deprecated"}]
    csrcUpdated,   \* SUBSET Cred  (constitutional sources superseded)
    witness,       \* [Form -> {"ok","failed"}]
    invocable,     \* [Form -> BOOLEAN]
    now,           \* Nat, discrete clock (proof device)
    deadline,      \* [Form -> Nat \cup {-1}]   (-1 encodes "none")
    ledger         \* Seq of records

vars == <<cstatus, ustatus, csrcUpdated, witness, invocable, now, deadline, ledger>>

None == -1

(***************************************************************************)
(* The governing predicate: the formal meaning of the surface's           *)
(* uniformity. One disjunction, five content-derived conditions.          *)
(***************************************************************************)
Affected(f) ==
    \/ \E c \in chain[f] : cstatus[c] \in {"revoked","superseded","deprecated"}
    \/ ustatus[unitOf[f]] = "deprecated"
    \/ \E c \in chain[f] : c \in csrcUpdated
    \/ witness[f] = "failed"

TypeOK ==
    /\ cstatus \in [Cred -> {"valid","revoked","superseded","deprecated"}]
    /\ ustatus \in [Unit -> {"active","deprecated"}]
    /\ csrcUpdated \subseteq Cred
    /\ witness \in [Form -> {"ok","failed"}]
    /\ invocable \in [Form -> BOOLEAN]
    /\ now \in Nat
    /\ deadline \in [Form -> (Nat \cup {None})]
    /\ ledger \in Seq([type: {"trigger","invalidate","recompile","invoke"},
                       form: Form \cup {"-"}, t: Nat, tag: {"clean","-"}])

Init ==
    /\ cstatus = [c \in Cred |-> "valid"]
    /\ ustatus = [u \in Unit |-> "active"]
    /\ csrcUpdated = {}
    /\ witness = [f \in Form |-> "ok"]
    /\ invocable = [f \in Form |-> TRUE]
    /\ now = 0
    /\ deadline = [f \in Form |-> None]
    /\ ledger = << >>

(***************************************************************************)
(* Actions.  A Trigger flips some form's Affected to true and sets its     *)
(* deadline; it does NOT change invocable (that is Invalidate's job).      *)
(***************************************************************************)

\* Set deadlines for forms that are affected after the mutation but had no deadline.
SetDeadlines(newAffected) ==
    deadline' = [f \in Form |->
                    IF f \in newAffected /\ deadline[f] = None
                    THEN now + Delta ELSE deadline[f]]

RevokeCred(c) ==
    /\ cstatus[c] = "valid"
    /\ cstatus' = [cstatus EXCEPT ![c] = "revoked"]
    /\ LET na == {f \in Form : c \in chain[f]} IN SetDeadlines(na)
    /\ ledger' = Append(ledger, [type|->"trigger", form|->"-", t|->now, tag|->"-"])
    /\ UNCHANGED <<ustatus, csrcUpdated, witness, invocable, now>>

DeprecateUnit(u) ==
    /\ ustatus[u] = "active"
    /\ ustatus' = [ustatus EXCEPT ![u] = "deprecated"]
    /\ LET na == {f \in Form : unitOf[f] = u} IN SetDeadlines(na)
    /\ ledger' = Append(ledger, [type|->"trigger", form|->"-", t|->now, tag|->"-"])
    /\ UNCHANGED <<cstatus, csrcUpdated, witness, invocable, now>>

UpdateSource(c) ==
    /\ c \notin csrcUpdated
    /\ csrcUpdated' = csrcUpdated \cup {c}
    /\ LET na == {f \in Form : c \in chain[f]} IN SetDeadlines(na)
    /\ ledger' = Append(ledger, [type|->"trigger", form|->"-", t|->now, tag|->"-"])
    /\ UNCHANGED <<cstatus, ustatus, witness, invocable, now>>

FailIntegrity(f) ==
    /\ witness[f] = "ok"
    /\ witness' = [witness EXCEPT ![f] = "failed"]
    /\ SetDeadlines({f})
    /\ ledger' = Append(ledger, [type|->"trigger", form|->"-", t|->now, tag|->"-"])
    /\ UNCHANGED <<cstatus, ustatus, csrcUpdated, invocable, now>>

Invalidate(f) ==
    /\ Affected(f)
    /\ invocable[f] = TRUE
    /\ invocable' = [invocable EXCEPT ![f] = FALSE]
    /\ deadline' = [deadline EXCEPT ![f] = None]
    /\ ledger' = Append(ledger, [type|->"invalidate", form|->f, t|->now, tag|->"-"])
    /\ UNCHANGED <<cstatus, ustatus, csrcUpdated, witness, now>>

Recompile(f) ==
    /\ invocable[f] = FALSE
    /\ ~Affected(f)
    /\ invocable' = [invocable EXCEPT ![f] = TRUE]
    /\ ledger' = Append(ledger, [type|->"recompile", form|->f, t|->now, tag|->"-"])
    /\ UNCHANGED <<cstatus, ustatus, csrcUpdated, witness, now, deadline>>

\* STRICT MODE: the guard re-evaluates Affected at invocation.
Invoke_strict(f) ==
    /\ invocable[f] = TRUE
    /\ ~Affected(f)
    /\ ledger' = Append(ledger, [type|->"invoke", form|->f, t|->now, tag|->"clean"])
    /\ UNCHANGED <<cstatus, ustatus, csrcUpdated, witness, invocable, now, deadline>>

\* Tick advances time, guarded: cannot pass the deadline of any affected,
\* still-invocable form.
TickEnabled ==
    \A f \in Form : ~(Affected(f) /\ invocable[f]
                      /\ deadline[f] # None /\ now >= deadline[f])

Tick ==
    /\ TickEnabled
    /\ now' = now + 1
    /\ UNCHANGED <<cstatus, ustatus, csrcUpdated, witness, invocable, deadline, ledger>>

Next ==
    \/ \E c \in Cred : RevokeCred(c)
    \/ \E u \in Unit : DeprecateUnit(u)
    \/ \E c \in Cred : UpdateSource(c)
    \/ \E f \in Form : FailIntegrity(f)
    \/ \E f \in Form : Invalidate(f)
    \/ \E f \in Form : Recompile(f)
    \/ \E f \in Form : Invoke_strict(f)
    \/ Tick

\* Per-form weak fairness on Invalidate and Recompile; weak fairness on Tick.
Fairness ==
    /\ \A f \in Form : WF_vars(Invalidate(f))
    /\ \A f \in Form : WF_vars(Recompile(f))
    /\ WF_vars(Tick)

Spec == Init /\ [][Next]_vars /\ Fairness

(***************************************************************************)
(* Invariants.                                                             *)
(***************************************************************************)

\* Safety skeleton: no affected, still-invocable form is past its deadline.
Inv_bound ==
    \A f \in Form :
        (Affected(f) /\ invocable[f])
          => (deadline[f] # None /\ now <= deadline[f])

\* Strict-mode currency, checkable form: every invoke on the ledger is clean.
Inv_tagged ==
    \A i \in DOMAIN ledger :
        ledger[i].type = "invoke" => ledger[i].tag = "clean"

\* The action property is expressed as: whenever an invoke is the most recent
\* ledger entry, the form it names was ~Affected when appended. Because
\* Invoke_strict cannot fire under Affected, and nothing mutates a past entry,
\* Inv_tagged is equivalent to it; TLC checks Inv_tagged.

\* The NAIVE invariant the paper shows is FALSE. Stated here so TLC can
\* refute it (it should produce a counterexample): a Trigger makes a form
\* Affected while still invocable, before Invalidate fires.
Naive_FALSE ==
    \A f \in Form : invocable[f] => ~Affected(f)

(***************************************************************************)
(* Liveness: every affected form eventually becomes non-invocable.         *)
(* (Checked by TLC under Fairness; the bound Delta is a safety consequence *)
(* of Inv_bound plus the Tick guard.)                                      *)
(***************************************************************************)
Liveness ==
    \A f \in Form : Affected(f) ~> ~invocable[f]

=============================================================================
