# ADR 003 — install.sh vendors core into each target repo

**Decision.** One installer (`install.sh`) copies `core/` into the target's
`.aidd/framework/` (version-pinned) instead of referencing a shared install location.
`/aidd:init` and `/aidd:upgrade` run the same steps.
**Why.** Self-containment: a Codex teammate can run the pipeline on a repo initialized by
a Claude teammate with zero setup; CI and history pin the exact framework version used.
**Consequence.** Framework updates are explicit per-repo (`/aidd:upgrade` re-vendors;
user artifacts are never touched). The vendored copy is write-protected by the
guard-scope hook on Claude Code.
