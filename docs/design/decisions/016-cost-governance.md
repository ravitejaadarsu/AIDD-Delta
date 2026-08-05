# ADR 016 — Actual spend is metered per dispatch, and running out stops the run

**Decision.** Every change carries two cost ceilings — `budget_tokens` and
`budget_minutes` — seeded from its rigor mode and recorded in change state under `cost`. The
orchestrator appends one row to `cost/ledger.md` after **every** dispatch returns; a runtime
that exposes no usage records `not measured`, never a zero. A deterministic projection
(remaining planned dispatches per `core/protocol/dispatch.md` × the running median of that
dispatch class, with a stated tie rule) is recomputed after every append. Three thresholds
have three distinct behaviors: **soft** (70%) reports in the progress line, **hard** (100%)
STOPs and asks — a forced-human gate in both autonomy modes with exactly four dispositions —
and **runaway** (one dispatch ≥ 5× its class median) aborts that dispatch and records it
without retrying. One new mode-independent quality gate, `within_cost_budget`, closes the
loop. Recording any quality gate `na` for cost reasons is forbidden and Supervisor-checkable.

**Why.** The most credible criticism of this framework is that it is expensive: three
verification layers, exhaustive test teams, adversarial verification, tally, negotiation,
supervision. Rigor modes (ADR 010) answered "how much *should* run"; nothing answered "what
did it *actually* cost, and what happens when that is more than the user is willing to
spend". Without a meter the failure mode is not a big invoice — it is a user who kills the
run halfway and never comes back, or an agent that quietly economizes by verifying less and
reports a green run anyway. The projection had to be arithmetic rather than a model so two
runs over the same ledger produce the same number and a stop is never a judgment call. And
the hard stop had to be a *stop*, not an automatic reduction: an agent that responds to cost
pressure by lowering its own standards is precisely the behavior AIDD exists to prevent, so
the only paths out are ones a human chooses and the ledger records.

**Consequence.** The capability costs something itself, and the honest accounting is: one
ledger append plus one projection recompute per dispatch (a state write the protocol already
requires and a few dozen lines of arithmetic — no model call), plus one more markdown artifact
per change, plus one more quality gate to satisfy. That is real overhead measured in state
writes, not in tokens. The budget numbers shipped are **derived, not measured** — no run in
this repository has had its token cost measured, so the defaults are a formula
(`planned_dispatches × 40,000`) and the file says so plainly; `bench/harness.md` is what will
replace them with medians. A runtime that hides usage still gets a governed run because
wall-clock is always measurable and the minutes ceiling is always enforceable — but its token
projection is a lower bound, and it is labelled as one. The deliberate asymmetry is that cost
pressure can pause a run and can never shrink it: if the budget cannot buy the floor, that is
a scope or budget decision for a human, and the framework says so rather than solving it
quietly.
