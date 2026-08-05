# ADR 012 — A closed command manifest, loaded before any reasoning

**Decision.** The command surface is a manifest — `core/scripts/aidd-commands.txt`, one row
per file in `commands/`, binding each command to the exact playbook or protocol file it
runs. Only manifest rows are commands; skills are explicitly not commands; and the
orchestrator must read the bound file from disk before producing any plan, question, state
write, or dispatch. `core/protocol/command-contract.md` is normative on every runtime; a
PreToolUse hook (`hooks/scripts/guard-command.sh`) enforces it mechanically on Claude Code
by denying unknown `/aidd:` tokens with the manifest's nearest match.
**Why.** Two observed failures share one root cause — a plausible name is enough for a
model to start reasoning. A session treated `/aidd:aidd-supervision` (a skill name) as a
command, and another invented orchestration around `/aidd:qa` rather than executing
`playbooks/40-qa.md`. Improvised phase logic looks correct and silently skips the roles,
gates, and evidence duties that make AIDD's output trustworthy. Closing the surface removes
the guess; ordering the load before the reasoning removes the improvisation. Deriving the
manifest from `commands/` rather than hand-listing it means the surface cannot drift from
what actually ships — a test asserts the 1:1 mapping in both directions.
**Consequence.** Adding a command is now two steps (the command file plus its manifest
row), and `tests/commands.test.sh` fails until both exist — deliberate friction on the
surface that users depend on. The hook is belt-and-braces, not the control: it only fires
inside an AIDD repo with a vendored manifest and degrades silently on anything it cannot
parse, so the protocol still carries portability. Reasoning that precedes the load is a
supervision violation, which means the Supervisor — not the user — catches the regression.
