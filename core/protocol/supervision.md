# Supervision Protocol

The Supervisor is the framework's internal QA of the process itself. It audits every
agent flow — including the orchestrator.

## Audit log

Every dispatch appends one line to `.aidd/changes/<id>/supervision/audit.log`:

```text
<ISO-8601> | <phase> | <role> | <story-or-scope> | dispatched|returned|rejected | <note>
```

On Claude Code the `session-log` hook appends automatically; on other runtimes the
orchestrator appends per protocol.

## Phase-boundary audit

At every phase end (before the phase is marked complete) the Supervisor replays the audit
log and artifacts against the phase checklist in the corresponding playbook. Checks include:

- Inception: clarifying questions asked/answered before PRD; judge scorecards present;
  disjointness verified; pre-review findings resolved or waived; gate hashes recorded.
- Construction: per-story failing-test evidence precedes implementation evidence; diffs
  confined to ownership sets; integration green evidence present; a Master Agent monitoring
  note present for every wave (`audit/monitoring/*`); Auditor interrogation verdicts
  complete for every wave (each claimed AC exactly `PROVEN` or `DISPUTED`); audit budgets
  respected — interrogation ≤ 2 rounds per subject, negotiation ≤ 2 exchanges per disputed
  AC, counters in change-state `audit` matching the artifacts on disk.
- QA: every CRITICAL/HIGH finding has a verdict; fix loop within budget; E2E clean-state
  evidence; post captures present; AC matrix complete; debate records present
  (`audit/debate/*`) with their budget arithmetic consistent with change-state
  `audit.debate` (exchanges counted in the records equal `exchanges_used`, within `max`);
  tally complete (`qa/tally.md`) with zero unwaived `GAP` rows and no unrouted orphans;
  negotiation log terminal — every disputed AC closed by short-circuit, accept, or
  Supervisor ruling, no dangling `DISPUTED`.
- Delivery: PR body embeds verdict table, funnel, AC matrix, evidence links; CI watched.

## Verdicts

`COMPLIANT` or `VIOLATIONS` (itemized: rule, evidence of breach, required remediation).
Written to `supervision/<phase>-report.md`; per-phase result mirrored into change-state
`supervision`. Any VIOLATION blocks phase advance until the violated step re-runs. A
repeated violation of the same rule = phase FAIL + human escalation. The final session
report summarizes all phases and appears in the delivery report and PR body.
