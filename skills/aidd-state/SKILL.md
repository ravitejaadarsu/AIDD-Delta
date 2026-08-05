---
name: aidd-state
description: AIDD state read/write discipline — single writer, write-then-rename, validate after every write, resume rules. Use whenever reading or writing .aidd/state.yaml or changes/*/state.yaml.
---

# AIDD State Skill

**This is a skill, not a command** — there is no `/aidd:aidd-state`. Skills are
instruction sets the orchestrator loads; before acting, load the exact playbook the
command contract binds to the invoked command (`.aidd/framework/protocol/command-contract.md`).

Follow `.aidd/framework/protocol/state-protocol.md` exactly. Key rules: only the
orchestrator writes state; write-temp-then-rename; validate with
`python3 .aidd/framework/scripts/aidd-validate.py` after every write; update state after
every completed step; on resume re-prove the current phase before continuing. After each
state write, regenerate the dashboard: `bash .aidd/framework/scripts/render-dashboard.sh`.
