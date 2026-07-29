---
description: Run the AIDD QA phase
---

**Preflight — the framework must be present.** If `.aidd/framework/` does not exist in this repo, AIDD is not initialized here. STOP and run `/aidd:init` first (it vendors the framework from the installed plugin), or tell the user this repo isn't AIDD-initialized. Do NOT improvise phase logic, invent a playbook, or run ad-hoc tests — running the real vendored playbook is the entire point.

Read `.aidd/framework/playbooks/40-qa.md` and execute it exactly. Requires Construction complete.
