---
description: Re-vendor the AIDD framework in this repo from the installed plugin
---

Refresh the vendored framework in this repo from the installed plugin.

1. Resolve PLUGIN_DIR as in `/aidd:init` (`$CLAUDE_PLUGIN_ROOT`, else the newest
   `~/.claude/plugins/cache/*/aidd/*/` containing `install.sh` + `core/`).
2. Re-run `AIDD_SRC="$PLUGIN_DIR" "$PLUGIN_DIR/install.sh"` to re-vendor `.aidd/framework/`
   (user artifacts — constitution, memory, learnings, state, changes — are never touched).
3. Report what changed (diff the framework `VERSION` and note new playbooks/roles).
   To pull a newer AIDD version first, run `claude plugin update aidd`, then this command.
