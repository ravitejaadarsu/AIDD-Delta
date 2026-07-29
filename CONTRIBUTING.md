# Contributing to AIDD Delta

## The one rule that matters

**`core/` is the single source of truth.** All phase logic, gate semantics, and state
protocol live in the portable markdown under `core/`. The Claude Code plugin layer
(`commands/`, `agents/`, `skills/`, `hooks/`) must only *reference* core playbooks —
never restate them. If the same rule appears in two files, that is a bug: fix it by
deleting the copy outside `core/`.

## Making changes

1. Edit the relevant file under `core/` (playbook, role, protocol, template, or schema).
2. If you changed a YAML template or schema, update fixtures in `tests/fixtures/`.
3. Run the self-tests: `tests/run.sh`. Everything must pass with zero external
   dependencies (bash + python3 stdlib only). shellcheck/markdownlint run when installed.
4. If you added or renamed a file, `tests/refs.test.sh` will fail until every reference
   to it (in any markdown or manifest) is consistent — fix all references.
5. Version bumps go through `scripts/bump-version.sh` (single source: `VERSION`).

## Design decisions

Significant decisions are recorded as ADRs in `docs/design/decisions/`. Add one when you
change an architectural rule (state protocol, gate semantics, installer behavior).
