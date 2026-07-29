---
description: Set AIDD autonomy mode (take-care or let-me-look): $ARGUMENTS
---

**Preflight — the framework must be present.** If `.aidd/framework/` does not exist in this repo, AIDD is not initialized here. STOP and run `/aidd:init` first (it vendors the framework from the installed plugin), or tell the user this repo isn't AIDD-initialized. Do NOT improvise phase logic, invent a playbook, or run ad-hoc tests — running the real vendored playbook is the entire point.

Set the AIDD mode to $ARGUMENTS per `.aidd/framework/protocol/autonomy-modes.md`: update the active change state (and global default if the user says so), record a history event, validate the state file.
