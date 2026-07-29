---
description: Install/refresh AIDD in this repo, then run the Master interview if needed
---

Initialize AIDD Delta in the current repository using the installed plugin — no separate
checkout required.

1. Resolve the AIDD plugin directory (PLUGIN_DIR), which bundles `core/` and `install.sh`:
   - if `$CLAUDE_PLUGIN_ROOT` is set, use it;
   - else use the newest match of `~/.claude/plugins/cache/*/aidd/*/` that contains both
     `install.sh` and `core/` (e.g. `~/.claude/plugins/cache/aidd-delta/aidd/<version>`).
2. Run the installer against this repo:
   `AIDD_SRC="$PLUGIN_DIR" "$PLUGIN_DIR/install.sh"`.
   This vendors the framework into `.aidd/framework/`, patches `AGENTS.md`, and seeds
   `.aidd/state.yaml` — without touching any existing constitution, memory, learnings,
   state, or changes.
3. If `.aidd/state.yaml` reports `constitution: missing`, read
   `.aidd/framework/playbooks/10-master.md` and execute it exactly (the Master interview).
