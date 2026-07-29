# AIDD Delta

**An autonomous multi-agent engineering fabric — one prompt to a merge-ready, CI-green PR.**

AIDD Delta is an orchestrated fleet of specialist agents that carries a single intent —
a feature request, a Jira ticket, a bug report — end to end: spec synthesis, judged
architecture, parallel test-first implementation, adversarially verified review,
exhaustive test generation, and evidence-backed sign-off, ending in a merge-ready pull
request with green CI. It self-audits the entire run, so nothing ships on assertion —
only on evidence.

It runs natively on **Claude Code** (true parallel subagents, hook-enforced guardrails)
and portably on **Codex CLI or any agent CLI** (the same playbooks, executed sequentially).

> Status: v0.1.0 scaffold under active construction. See [ROADMAP.md](ROADMAP.md).

## Why AIDD Delta

- **Precision over speed.** Requirements are clarified before anything is generated.
  Implementation is test-first with recorded failing-test evidence. Every review finding
  must survive an adversarial verifier that tries to refute it — only confirmed defects
  block. An exhaustive tester team then attacks each change with the possible and the
  impossible cases.
- **Staged, gated, resumable.** The run advances through discrete, evidence-gated stages
  with human checkpoints (requirements, plan, pre-merge) — or full autonomy with an
  identical audit trail. State is schema-validated and every step is resumable.
- **A supervisor over the supervisors.** An independent auditor inspects every agent
  hand-off at each stage boundary; the process itself is held to account, not just the code.
- **Portable core.** All logic is plain markdown in `core/`. The Claude Code integration
  is a thin shell; any agent CLI runs literally the same playbooks.

## Quickstart

- Claude Code: [docs/quickstart-claude.md](docs/quickstart-claude.md)
- Codex CLI / any agent CLI: [docs/quickstart-codex.md](docs/quickstart-codex.md)

## Layout

| Path | Purpose |
|---|---|
| `core/` | The portable framework: playbooks, roles, protocol, templates, schemas |
| `commands/`, `agents/`, `skills/`, `hooks/` | Claude Code plugin shell |
| `install.sh` | Universal installer — vendors `core/` into a target repo's `.aidd/` |
| `tests/` | Framework self-tests (zero-dependency bash + python3) |
| `docs/` | Human-oriented reference |

## License

MIT — see [LICENSE](LICENSE).
