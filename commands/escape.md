---
description: Analyze a defect that escaped to production — which layer went blind, and what changes: $ARGUMENTS
---

**Preflight — the framework must be present.** If `.aidd/framework/` does not exist in this repo, AIDD is not initialized here. STOP and run `/aidd:init` first (it vendors the framework from the installed plugin), or tell the user this repo isn't AIDD-initialized. Do NOT improvise phase logic, invent a playbook, or run ad-hoc tests — running the real vendored playbook is the entire point.

Run escape analysis for $ARGUMENTS (a defect description, an issue URL, or a change id) per `.aidd/framework/protocol/escape-analysis.md`: attribute the defective code to a merged AIDD change (`git log -S` / `git blame` → commit → `aidd/<change-id>`; no AIDD change owns it → record `out-of-scope` and stop), assign the next `E-NNN`, classify it with a `defect_class` from the shared vocabulary, then dispatch the Escape Analyst (`.aidd/framework/roles/escape-analyst.md`) to produce the nine-row per-layer verdict table and the two mandatory outputs — a regression test specification and one minimal protocol amendment proposal.

Then: check the register for a repeat (same defect class plus an already-blind layer) and, if it is one, escalate to the user with the prior amendment instead of re-proposing it; route the regression test into a fix change at **at least** the escaped change's rigor mode (TDD: RED before the fix, GREEN after); append the `escapes` row to the merged change's state and the row to `.aidd/escapes/register.md`; recompute the escape rate and per-layer blindness (always printing numerator and denominator, `not measured` when the window has no analyzed escape); and dispatch the Retro Learner as a retro addendum so the lessons land in the same `learnings.md`.

This is retrospective: it re-opens no phase, re-runs no gate, and blocks nothing. **The amendment is a proposal — never applied automatically.** Present it and let the user decide.
