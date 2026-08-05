---
description: Set or report AIDD rigor mode (fast, standard, or critical): $ARGUMENTS
---

**Preflight — the framework must be present.** If `.aidd/framework/` does not exist in this repo, AIDD is not initialized here. STOP and run `/aidd:init` first (it vendors the framework from the installed plugin), or tell the user this repo isn't AIDD-initialized. Do NOT improvise phase logic, invent a playbook, or run ad-hoc tests — running the real vendored playbook is the entire point.

Set the AIDD rigor mode to $ARGUMENTS per `.aidd/framework/protocol/rigor-modes.md`: update the active change state's `rigor` block (`mode`, `selected_by: user`, `reason` = the user's words verbatim), record a history event, validate the state file. An explicit choice PINS the mode — the classifier stops re-classifying — but automatic escalation still applies, and a downward pin is allowed only before Construction starts (in `take-care` it sets the escalation flag and stops at the next gate).

With no arguments, report the active change's current mode, who selected it, the reason, and any escalations — do not change anything.

Rigor is orthogonal to the autonomy mode (`/aidd:mode`): autonomy decides who approves, rigor decides how much verification runs.
