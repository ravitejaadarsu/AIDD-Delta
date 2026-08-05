# Quickstart — Codex CLI (Tier 2) and any other agent CLI (Tier 3)

The same pipeline, no plugin required. Everything the agent needs is plain markdown.

Your runtime sets your **tier**, and tier changes **parallelism and enforcement automation,
not correctness**: the playbooks, gate semantics, the fourteen quality gates, evidence rules,
and the artifact set are identical to a Claude Code run. Cell-by-cell:
[capability-matrix.md](capability-matrix.md).

## 1. Install into your repo

```bash
git clone https://github.com/ravitejaadarsu/AIDD-Delta.git ~/AIDD-Delta
cd your-project
~/AIDD-Delta/install.sh
```

This vendors the framework into `.aidd/framework/`, creates/patches `AGENTS.md`
(Codex reads it automatically), and seeds state.

## 2. Talk to your agent

**Tier 2 — Codex CLI.** Codex picks up the routing table in `AGENTS.md`, so natural language
works:

```text
AIDD: run the master phase
AIDD: build Add CSV export to the reports page
AIDD: status
AIDD: approve
AIDD: resume
```

**Tier 3 — any other CLI or a plain LLM session.** Paste the matching prompt from
`.aidd/framework/prompts/` (`go.md`, `status.md`, `resume.md`, or a phase prompt) into the
agent. Gate approvals can also be recorded by editing the change's `state.yaml` per
`.aidd/framework/protocol/gates.md` — state files are human-editable by design.

## What differs from Claude Code

Two things, and they are the whole list:

- **Speed.** Fan-out stages (story authors, builders per wave, reviewers per dimension,
  testers per category, judges) run **sequentially** in the documented order. Wall clock
  grows roughly with fan-out width. Artifacts and gates are identical, because roles
  communicate only through artifacts.
- **Enforcement.** There are no hooks, so four invariants become explicit orchestrator
  duties instead of mechanisms: keep writes inside the story's ownership set; run
  `python3 .aidd/framework/scripts/aidd-validate.py` after every state write; do not abandon
  a pending gate; append every dispatch to `supervision/audit.log`. The Supervisor's
  phase-boundary audit **detects** a lapse in any of these from the artifacts — it cannot
  prevent one. Treat the duties as non-optional.

Optional-tool differences (Playwright MCP live re-proof, Jira MCP pull) degrade along
documented paths with the taken path recorded — never a silent skip. See the matrix.

## First run

If you want a 15-minute offline first run against a bundled fixture instead of your own
repo, start at [adoption.md](adoption.md).
