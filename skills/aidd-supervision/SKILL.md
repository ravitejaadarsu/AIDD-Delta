---
name: aidd-supervision
description: AIDD Supervisor duties — audit log, phase-boundary compliance audits, violation remediation. Use at every phase boundary and when reviewing supervision reports.
---

# AIDD Supervision Skill

Follow `.aidd/framework/protocol/supervision.md` exactly. Every dispatch is logged to
`supervision/audit.log` (the plugin's Task hook does this automatically). At each phase
boundary dispatch `aidd-supervisor`; mirror its verdict into state; VIOLATIONS
block phase advance until the violated step re-runs.
