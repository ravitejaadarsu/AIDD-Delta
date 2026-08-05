---
name: aidd-gates
description: AIDD gate mechanics — digests, approve/revise/abort, hash-bound staleness, take-care auto-approval and escalation flags. Use at G1/G2/G3, on /aidd:approve or /aidd:revise, or when a gate shows stale.
---

# AIDD Gates Skill

**This is a skill, not a command** — there is no `/aidd:aidd-gates`. Skills are
instruction sets the orchestrator loads; before acting, load the exact playbook the
command contract binds to the invoked command (`.aidd/framework/protocol/command-contract.md`).

Follow `.aidd/framework/protocol/gates.md` exactly. Never advance past a gate without a
ledger entry; never treat an auto-approval differently from a human one in the audit
trail; artifact drift after approval flips the gate to stale and it must re-pass.
