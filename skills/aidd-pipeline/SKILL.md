---
name: aidd-pipeline
description: How to run the AIDD Delta pipeline in this repo. Use whenever the user asks to build/plan/qa/deliver a change with AIDD, mentions "AIDD:", or invokes any /aidd command. Canonical logic lives in .aidd/framework/playbooks/ — never improvise phase logic.
---

# AIDD Pipeline Skill

**This is a skill, not a command** — there is no `/aidd:aidd-pipeline`. Skills are
instruction sets the orchestrator loads; before acting, load the exact playbook the
command contract binds to the invoked command (`.aidd/framework/protocol/command-contract.md`).

1. Open `.aidd/framework/playbooks/00-pipeline.md` and follow it exactly.
2. You are the orchestrator: dispatch the roles in `.aidd/framework/roles/` as parallel
   subagents (the plugin registers each as `aidd-<role>`); you never write product code
   or product artifacts yourself.
3. Phase boundaries: dispatch `aidd-supervisor`; VIOLATIONS block advance.
4. Honor gates per `.aidd/framework/protocol/gates.md` and the mode per
   `.aidd/framework/protocol/autonomy-modes.md`.
