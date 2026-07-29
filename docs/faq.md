# FAQ

**Does take-care mode lower the quality bar?** No. Autonomy modes change who approves
gates, never the nine quality gates — those block delivery identically in both modes.

**What if my project has no UI?** Evidence capture degrades to CLI/API transcripts,
recorded explicitly in the manifest. No mutation tool for your stack? `mutation_floor_met`
records `na` with a reason.

**Can a teammate on Codex work in a repo I initialized with Claude Code?** Yes — the
target repo is self-contained (`.aidd/framework/` vendors everything, `AGENTS.md` routes).

**Why did my gate flip to stale?** An approved artifact changed after approval (hash
mismatch). Re-approve after reviewing the delta — that guarantee is what makes approvals
meaningful.

**How do I upgrade a repo's framework?** `/aidd:upgrade` (or re-run `install.sh`).
User artifacts (constitution, memory, learnings, state, changes) are never touched.

**Where does the pipeline stop in v1?** A merged-ready PR with green CI. Deployment,
merge automation, and post-merge canary watch are on the ROADMAP.
