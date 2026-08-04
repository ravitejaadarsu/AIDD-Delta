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
