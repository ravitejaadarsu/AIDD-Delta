---
description: Report AIDD cost — ledger summary, projection, and threshold status: $ARGUMENTS
---

**Preflight — the framework must be present.** If `.aidd/framework/` does not exist in this repo, AIDD is not initialized here. STOP and run `/aidd:init` first (it vendors the framework from the installed plugin), or tell the user this repo isn't AIDD-initialized. Do NOT improvise phase logic, invent a playbook, or run ad-hoc tests — running the real vendored playbook is the entire point.

Report the active change's cost per `.aidd/framework/protocol/cost-governance.md`: run `bash .aidd/framework/scripts/aidd-cost.sh` (add `--ledger <path>` for a specific change, `--json <dir>` where the runtime writes per-dispatch usage files) and relay its summary — spend against both ceilings, per-phase totals, per-class medians, the projection with its lower-bound marker when a class is unknown, threshold status, and any `stops` row still `pending`. Embed the run as an evidence block (`.aidd/framework/protocol/evidence.md`).

$ARGUMENTS may name a change id, a ledger path, or a threshold to explain. With no arguments, report the active change.

This command **computes and reports only**. It never edits state, never edits the ledger, and never picks a disposition: a hard-threshold stop is a forced-human decision in both autonomy modes (raise the budget, reduce breadth where rigor already permits, narrow scope, or abort), and a soft crossing is a report that changes nothing. A cost number never justifies recording a quality gate `na` — cost pressure produces a STOP, never a quieter run.
