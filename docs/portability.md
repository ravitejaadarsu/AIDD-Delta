# Portability

**The portable core is the product; the Claude Code plugin is a thin shell.**

- All phase logic, gate semantics, state protocol, roles, templates, and schemas live in
  `core/` as plain markdown/YAML/JSON — vendored into every target repo at
  `.aidd/framework/`.
- The plugin layer (`commands/`, `agents/`, `skills/`, `hooks/`) only *references* the
  vendored core. If logic appears in both places, that is a bug (see CONTRIBUTING.md).
- Codex CLI reads `AGENTS.md` natively; other CLIs use `.aidd/framework/prompts/`.
- Fan-outs degrade to sequential execution in the documented order. Roles communicate
  only through artifacts, so parallel and sequential runs converge on identical outputs.
- The only hard runtime dependencies anywhere: bash + python3 (stdlib). Playwright and
  scanners are optional and degrade explicitly (`core/protocol/evidence.md`).
