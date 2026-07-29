# Quickstart — Claude Code

Five minutes from zero to your first AIDD change.

## 1. Install the plugin

```bash
git clone https://github.com/aidd-delta/AIDD-Delta.git ~/AIDD-Delta
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
- The result is a merged-ready PR: quality verdicts, findings funnel, AC matrix,
  before/after evidence, supervision report — all in the PR body.

## Phase-by-phase (optional)

`/aidd:document` (brownfield mining) · `/aidd:master` · `/aidd:inception "<intent>"` ·
`/aidd:construct` · `/aidd:qa` · `/aidd:deliver`
