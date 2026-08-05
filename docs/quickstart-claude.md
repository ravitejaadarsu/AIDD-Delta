# Quickstart — Claude Code (Tier 1)

Five minutes from zero to your first AIDD change, on the **full** capability surface:
parallel subagent dispatch, hook-enforced protocol invariants, and the `/aidd:*` commands.
What that buys you over other runtimes — and what it does not — is spelled out in
[capability-matrix.md](capability-matrix.md). Short version: tier changes parallelism and
enforcement automation, not correctness.

## 1. Install the plugin

```bash
git clone https://github.com/ravitejaadarsu/AIDD-Delta.git ~/AIDD-Delta
```

In Claude Code: `/plugin marketplace add ~/AIDD-Delta` → install the **aidd** plugin.
(Or use the repo path directly if your Claude Code version supports local plugin dirs.)

## 2. Initialize your repo

Inside your project, run `/aidd:init`. This vendors the framework into
`.aidd/framework/`, patches `AGENTS.md`, seeds state, and runs the Master interview
(constitution: stack, canonical commands, quality bars).

## 3. Run an intent

```text
/aidd:go "Add CSV export to the reports page"
/aidd:go "PROJ-123"          # or straight from a Jira ticket
```

Default mode is `let-me-look`: the pipeline pauses at G1 (PRD), G2 (plan), and
G3 (pre-merge) — respond with `/aidd:approve` or `/aidd:revise "..."`. Prefer full
autonomy? `/aidd:mode take-care` first.

## 4. Watch and steer

- `/aidd:status` — where things stand · `/aidd:dashboard` — visual pipeline view
- `/aidd:resume` — continue after any interruption
- The result is a merge-ready PR: quality verdicts, findings funnel, AC matrix,
  before/after evidence, supervision report — all in the PR body. AIDD does not merge.

## What Tier 1 gives you

- **Parallel fan-outs.** Story authors, per-wave builders, per-dimension reviewers,
  per-category testers, and architecture judges run concurrently, each in its own context
  window.
- **Hook enforcement.** Five hooks make protocol invariants mechanical rather than
  aspirational: scope guard, state schema validation, pending-gate check on stop, snapshot
  refresh, dispatch audit logging (`hooks/hooks.json`).
- **MCP-backed capabilities where connected.** Playwright MCP for live re-proof of disputed
  UI test results, Atlassian MCP for Jira pull. Without those servers this session degrades
  along the documented Tier 2 paths — the matrix says exactly how.

Everything else — the playbooks, the gates, the quality bars, the artifact set — is identical
to what a Codex CLI or plain-LLM run produces. See
[quickstart-codex.md](quickstart-codex.md) for the sequential path.

## Phase-by-phase (optional)

`/aidd:document` (brownfield mining) · `/aidd:master` · `/aidd:inception "<intent>"` ·
`/aidd:construct` · `/aidd:qa` · `/aidd:deliver`
