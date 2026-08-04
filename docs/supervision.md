# Supervision

The Supervisor is AIDD's answer to "who watches the watchers": a session-wide
auditor that checks the *process* at every phase boundary — including the orchestrator's
own conduct. Canonical: `core/protocol/supervision.md`; role:
`core/roles/supervisor.md`.

- Every dispatch lands in `supervision/audit.log` (automatic on Claude Code via the Task
  hook; protocol duty elsewhere).
- At each phase end the Supervisor replays the log + artifacts against the playbook's
  checklist: TDD ordering, gate hashes, ownership confinement, evidence presence, no
  skipped steps.
- COMPLIANT → phase advances. VIOLATIONS → the violated step re-runs first; a repeat of
  the same violation fails the phase and escalates to you.
- The final session report appears in the delivery report and the PR body — so reviewers
  see not just *what* shipped but proof of *how* it was built.

## The super-context

Since v0.3.0 the Supervisor is Layer 3 of [three-layer verification](three-layer-verification.md),
and its audit reads more than the audit log. Beyond the phase's Layer-1 artifacts, it
reads the whole Layer-2 record — the **super-context**: `audit/monitoring/*` (Master
Agent quality notes), `audit/interrogation/*` (Auditor challenges, responses, and per-AC
verdicts), `audit/negotiation-log.md`, `audit/debate/*`, `qa/tally.md`, and the Critic
verdict. This is what makes the Supervisor's second duty possible.

## Adjudication duty

Where a disputed acceptance criterion's Auditor ↔ Master Agent negotiation
(`core/protocol/negotiation.md`) spends its full budget — two exchanges — with the
Master Agent still contesting, it escalates to the Supervisor. The Supervisor rules from
the super-context, never from the exchanged positions alone, exactly one of `PROVEN |
DEFECT | UNRESOLVABLE` per AC:

- **PROVEN** — the dispute doesn't hold; the work stands.
- **DEFECT** — the work is deficient; the AC re-enters the fix loop, same as an executed
  test FAIL.
- **UNRESOLVABLE** — the super-context genuinely doesn't settle it; a forced-human gate
  in both autonomy modes, take-care included.

Each ruling is appended as exactly one line to `audit/negotiation-log.md` (who ruled:
Supervisor adjudication) and mirrored into change state — never a third phase verdict:
the phase-compliance vocabulary stays exactly `COMPLIANT | VIOLATIONS`, with adjudication
as a distinct additional output.
