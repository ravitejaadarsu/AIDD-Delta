# ADR 011 — Dispatch comes from a decision table, and is never re-decided within a step

**Decision.** Agent count, file ownership, parallel-vs-sequential, cap, and order are
resolved by lookup in the decision table in `core/protocol/dispatch.md`, keyed by
`(phase, unit-of-work, rigor mode)` — not by orchestrator judgment. Parallel dispatch is
permitted only when the units' ownership sets are provably pairwise disjoint
(`core/protocol/file-scope.md`); unproven ⇒ sequential in the row's documented deterministic
order (story-id / dimension / category / subject-id / ac-id ascending). The resolved plan is
recorded once in `supervision/audit.log` and executed as recorded. **Re-deciding a plan
mid-step is a supervision VIOLATION**, evidenced by two plan lines for one step token or
dispatches that do not match the plan.
**Why.** Re-deciding fan-out every step was the framework's largest source of overhead and
drift: the same step took a different shape on every run, ownership got re-litigated in
prose, "should this be parallel?" was re-answered from scratch with the code in front of it,
and nothing afterwards could say what was supposed to happen. A table has none of those
failure modes — it is cheap to consult, identical across runs and runtimes, and mechanically
auditable. Making disjointness a proof obligation rather than a judgment call removes the
one place where improvisation could corrupt the product: two agents writing the same file.
**Consequence.** The orchestrator's freedom is deliberately gone. A step whose right shape
genuinely differs is a table change (reviewed, versioned) rather than a per-run decision, and
a step whose scope changed mid-flight — backflow delta stories, an escalated rigor mode —
opens a NEW step with a new token and its own single plan instead of amending the old one.
Units beyond the cap queue in the documented order and are never dropped and never
over-spawned, so a step's context and audit trail stay bounded. Runtimes without parallelism
run the same units, same count, same order, one at a time, with `mode=sequential
reason=runtime-no-parallel` recorded — the fallback is a degradation that is stated, not a
different plan.
