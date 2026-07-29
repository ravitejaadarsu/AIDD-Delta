---
description: Run the full AIDD pipeline for an intent (or Jira key): $ARGUMENTS
---

**Preflight — the framework must be present.** If `.aidd/framework/` does not exist in this repo, AIDD is not initialized here. STOP and run `/aidd:init` first (it vendors the framework from the installed plugin), or tell the user this repo isn't AIDD-initialized. Do NOT improvise phase logic, invent a playbook, or run ad-hoc tests — running the real vendored playbook is the entire point.

Read `.aidd/framework/playbooks/00-pipeline.md` and execute it exactly with intent: $ARGUMENTS. Honor the mode in `.aidd/state.yaml` unless the user specified one.
