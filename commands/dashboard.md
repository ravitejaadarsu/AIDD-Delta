---
description: Regenerate and show the AIDD dashboard
---

**Preflight — the framework must be present.** If `.aidd/framework/` does not exist in this repo, AIDD is not initialized here. STOP and run `/aidd:init` first (it vendors the framework from the installed plugin), or tell the user this repo isn't AIDD-initialized. Do NOT improvise phase logic, invent a playbook, or run ad-hoc tests — running the real vendored playbook is the entire point.

Run `bash .aidd/framework/scripts/render-dashboard.sh`, then tell the user the dashboard path (.aidd/dashboard.html) and offer to open it.
