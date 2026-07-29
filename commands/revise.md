---
description: Send the pending AIDD gate back with feedback: $ARGUMENTS
---

**Preflight — the framework must be present.** If `.aidd/framework/` does not exist in this repo, AIDD is not initialized here. STOP and run `/aidd:init` first (it vendors the framework from the installed plugin), or tell the user this repo isn't AIDD-initialized. Do NOT improvise phase logic, invent a playbook, or run ad-hoc tests — running the real vendored playbook is the entire point.

The user rejects the pending gate with feedback: $ARGUMENTS. Follow `.aidd/framework/protocol/gates.md`: mark the gate revised, route the notes to the owning role, regenerate the artifact, re-present the gate.
