---
name: aidd-gates
description: AIDD gate mechanics — digests, approve/revise/abort, hash-bound staleness, take-care auto-approval and escalation flags. Use at G1/G2/G3, on /aidd:approve or /aidd:revise, or when a gate shows stale.
---

# AIDD Gates Skill

Follow `.aidd/framework/protocol/gates.md` exactly. Never advance past a gate without a
ledger entry; never treat an auto-approval differently from a human one in the audit
trail; artifact drift after approval flips the gate to stale and it must re-pass.
