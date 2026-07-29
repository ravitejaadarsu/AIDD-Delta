---
description: Run AIDD impact analysis — blast radius of a change through multiple lenses: $ARGUMENTS
---

**Preflight — the framework must be present.** If `.aidd/framework/` does not exist in this repo, AIDD is not initialized here. STOP and run `/aidd:init` first (it vendors the framework from the installed plugin), or tell the user this repo isn't AIDD-initialized. Do NOT improvise phase logic, invent a playbook, or run ad-hoc tests — running the real vendored playbook is the entire point.

Run the AIDD Impact Analyst on the target: $ARGUMENTS (a change-id, a diff, or a described
change; defaults to the active change). Read `.aidd/framework/roles/impact-analyst.md` and
follow it exactly, producing `impact-report.md` (blast-radius rating + lenses with cited
call sites). Report the rating and the top risk.
