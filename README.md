# AIDD Delta

**One intent → production-ready delivery.**

AIDD Delta is a multi-agent, AI-driven development framework. You give it a single
intent — a feature request, a Jira ticket, a bug report — and it drives the full
lifecycle: requirements, architecture, parallel TDD implementation, adversarially
verified review, evidence-backed QA, and a merged-ready pull request with green CI.

It runs natively on **Claude Code** (true parallel subagents, hook-enforced guardrails)
and portably on **Codex CLI or any agent CLI** (the same playbooks, executed sequentially).

> Status: v0.1.0 scaffold under active construction. See [ROADMAP.md](ROADMAP.md).

## Why AIDD Delta

- **Precision over speed.** Clarifying questions before generation. TDD with recorded
  failing-test evidence. Every review finding must survive an adversarial verifier that
  tries to refute it. Nothing ships on assertion — only on evidence.
- **Five phases, three gates.** Master → Inception → Construction → QA → Delivery, with
  human approval gates (PRD, Plan, Pre-merge) — or fully autonomous `take-care` mode
  with an identical audit trail.
- **A Master Supervisor** audits every agent flow at every phase boundary. The process
  itself is QA'd.
- **Portable core.** All logic is plain markdown in `core/`. The Claude Code plugin is a
  thin shell; a Codex user runs literally the same playbooks.

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
