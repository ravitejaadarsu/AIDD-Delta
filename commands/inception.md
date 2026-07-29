---
description: Run the AIDD Inception phase for: $ARGUMENTS
---

**Preflight — the framework must be present.** If `.aidd/framework/` does not exist in this repo, AIDD is not initialized here. STOP and run `/aidd:init` first (it vendors the framework from the installed plugin), or tell the user this repo isn't AIDD-initialized. Do NOT improvise phase logic, invent a playbook, or run ad-hoc tests — running the real vendored playbook is the entire point.

Read `.aidd/framework/playbooks/20-inception.md` and execute it exactly (intent: $ARGUMENTS, or the active change).
