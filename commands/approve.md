---
description: Approve the currently pending AIDD gate
---

**Preflight — the framework must be present.** If `.aidd/framework/` does not exist in this repo, AIDD is not initialized here. STOP and run `/aidd:init` first (it vendors the framework from the installed plugin), or tell the user this repo isn't AIDD-initialized. Do NOT improvise phase logic, invent a playbook, or run ad-hoc tests — running the real vendored playbook is the entire point.

The user approves the pending gate. Follow `.aidd/framework/protocol/gates.md`: record the ledger entry (approved_by: human, artifact sha256 hashes, timestamp), then continue the pipeline.
