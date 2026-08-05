# ADR 010 — Verification cost is proportional to risk, chosen by classifier

**Decision.** Every change carries a **rigor mode** — `fast`, `standard` (default), or
`critical` — resolved at change creation by the deterministic classifier in
`core/protocol/rigor-modes.md` and recorded in change state (`rigor.mode`,
`selected_by`, `reason`, `escalations`). The mode sets breadth: which review dimensions,
how many test categories, whether Layer 2 and the test debate run at all, and the
interrogation/negotiation/debate budgets. It is orthogonal to the autonomy mode — autonomy
decides who approves, rigor decides how much runs. Escalation (`fast` → `standard` →
`critical`) is automatic and **one-way**; de-escalation does not exist.
**Why.** The v0.3.0 machinery — three verification layers, exhaustive test teams,
adversarial verification, tally, negotiation, supervision — is correct for an auth bypass
and indefensible for a button label. A framework that spends the same on both teaches its
users to route around it, which costs more than the tokens ever did. Selection had to be
evidence-based to be trustworthy: a classifier table matched against paths, story `risk`
markers, and the intent's own words, so two runs of the same change resolve the same mode
and the reason is auditable. Ambiguity resolves upward, and the classifier never guesses
`fast`.
**Consequence.** A `fast` change skips Layer 2, E2E, mutation, and most dimensions and
categories — every one of those recorded `na` with `reason: rigor:fast`, never silently
absent, so the reduction is visible in the dashboard, the gate digest, and the PR body. The
floor is inviolable in all three modes (TDD evidence, disjoint ownership, evidence blocks
with exit codes, the Supervisor's process audit, the Critic verdict, human approval at G3 in
`let-me-look`): rigor reduces breadth, never honesty. Escalation costs a back-fill — the
skipped steps re-run in the new mode and every `na` earned under the outgone mode flips back
to `pending` — which is the price of having started cheap, and it is bounded. A
misclassification down is recoverable (evidence escalates it); a misclassification up merely
costs tokens. Both asymmetries point the same way, which is why upward is the only automatic
direction.
