# Quickstart — Codex CLI (or any agent CLI)

The same pipeline, no plugin required. Everything the agent needs is plain markdown.

## 1. Install into your repo

```bash
git clone https://github.com/aidd-delta/AIDD-Delta.git ~/AIDD-Delta
cd your-project
~/AIDD-Delta/install.sh
```

This vendors the framework into `.aidd/framework/`, creates/patches `AGENTS.md`
(Codex reads it automatically), and seeds state.

## 2. Talk to your agent

Codex picks up the routing table in `AGENTS.md`, so natural language works:

```text
AIDD: run the master phase
AIDD: build Add CSV export to the reports page
AIDD: status
AIDD: approve
AIDD: resume
```

Any other CLI: paste the matching prompt from `.aidd/framework/prompts/` (go, status,
resume, or a phase prompt) into the agent.

## What differs from Claude Code?

Only parallelism. Fan-out stages (story authors, builders, reviewers, verifiers) run
sequentially in the documented order; artifacts and gates are identical. Approvals can
also be recorded by editing the change's `state.yaml` per
`.aidd/framework/protocol/gates.md` — state files are human-editable by design.
