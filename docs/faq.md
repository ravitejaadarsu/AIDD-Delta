# FAQ

**Which runtime should I use, and does it change the result?** Your runtime sets your
**tier** — Tier 1 Claude Code, Tier 2 Codex CLI, Tier 3 any other agent CLI or plain LLM
session. Tier determines **parallelism and enforcement automation, not correctness**: the
playbooks, gate semantics, quality gates, evidence rules, and the artifact set are identical
on all three. Sequential tiers take proportionally longer, and off Claude Code the four
hook-enforced invariants become orchestrator duties that the Supervisor audits rather than
mechanisms that block. Cell-by-cell detail: [capability-matrix.md](capability-matrix.md).

**Does take-care mode lower the quality bar?** No. Autonomy modes change who approves
gates, never the fourteen quality gates — those block delivery identically in both modes.

**What if my project has no UI?** Evidence capture degrades to CLI/API transcripts,
recorded explicitly in the manifest. No mutation tool for your stack? `mutation_floor_met`
records `na` with a reason.

**Can a teammate on Codex work in a repo I initialized with Claude Code?** Yes — the
target repo is self-contained (`.aidd/framework/` vendors everything, `AGENTS.md` routes).
They run at Tier 2: same artifacts, sequential fan-outs, no hooks. A change can cross tiers
mid-run; `state.yaml` is the handoff.

**Why did my gate flip to stale?** An approved artifact changed after approval (hash
mismatch). Re-approve after reviewing the delta — that guarantee is what makes approvals
meaningful.

**How do I upgrade a repo's framework?** `/aidd:upgrade` (or re-run `install.sh`).
User artifacts (constitution, memory, learnings, state, changes) are never touched.

**Where does the pipeline stop in v1?** A merge-ready PR whose CI has been watched. AIDD
never merges for you. Deployment, merge automation, and post-merge canary watch are on the
ROADMAP.

**Are there published benchmark results?** Not yet. The harness ships in `bench/` with the
comparison arms and the defect corpus so you can run it yourself; nothing is published until
a run's artifacts back it ([benchmarks.md](benchmarks.md), [adoption.md](adoption.md)).
