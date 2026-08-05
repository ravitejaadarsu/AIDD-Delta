# ADR 013 — The user gets state transitions; deliberation is filed, not narrated

**Decision.** User-facing output during a run is one fixed-format progress line per
completed step — phase, step/total, what happened, evidence pointer, gates approved, rigor
mode, next step — with a distinct shape for blocked/failed steps naming the playbook's
prescribed remediation. Deliberation about agent counts, models, parallelism, re-litigated
plans, and playbook restatements is forbidden output. It goes to `supervision/audit.log` and
the phase report artifacts. Gate asks are the one exception and are capped at five lines.
`core/protocol/progress.md` is normative; the dashboard's **Recent progress** section is the
detail surface.
**Why.** Sessions narrated their deliberation instead of reporting state, which buries the
only two things a supervising human needs — where the run is, and what it needs from them —
under a monologue. The reasoning itself is not the problem and is not discarded: the
playbooks and decision tables already *are* the reasoning record, and the audit log plus
phase reports capture what a run actually deliberated. A fixed line is also
machine-parseable, so the same text serves the terminal, the change-state `history` event,
and the dashboard replay without a second format.
**Consequence.** Progress becomes predictable and cheap to scan, and a run that emits no
line has demonstrably changed no state — silence is now information. The cost is rigidity:
anything genuinely worth saying mid-run must find a home in an artifact or a gate ask, and
"no line for a step that did not change state" means a long-running step looks quiet until
it lands. The line references change-state `rigor.mode` as an optional field, printing `-`
when absent, so the contract holds on states written before rigor modes existed.
