# Command contract

AIDD's command surface is closed. `core/scripts/aidd-commands.txt` — vendored to
`.aidd/framework/scripts/aidd-commands.txt` — is the manifest: one row per command,
`<command>|<playbook-or-protocol path>|<one-line purpose>`, derived mechanically from
`commands/`. If a token has no row, it is not a command. Canonical rules:
`core/protocol/command-contract.md`.

Two field failures motivated it:

- a session treated **`/aidd:aidd-supervision` — a skill name — as a command**, and
- a session **invented orchestration around `/aidd:qa`** instead of running
  `playbooks/40-qa.md`.

## Skills are not commands

The four skills (`aidd-pipeline`, `aidd-state`, `aidd-gates`, `aidd-supervision`) are
instruction sets the orchestrator loads — they describe *how to behave*. A command's
playbook describes *what steps to execute*. No skill has a manifest row, so
`/aidd:aidd-pipeline` and friends do not exist. Loading a skill never substitutes for
loading the playbook.

## Load before reason

For any command, the orchestrator reads the exact file the manifest row names — from disk,
this session — **before** producing any plan, clarifying question, state write, or
subagent dispatch. The failure mode being prevented is improvised phase logic: a
plausible-sounding step sequence invented from a command's name, skipping the roles, gates,
and evidence duties the playbook mandates. Reasoning before the load is a supervision
violation (`core/protocol/supervision.md`), itemized like any other breach.

If no command covers what the user asked, the answer is to name the closest supported
command and stop. Never invent a phase, a gate key, a quality gate, or an agent flow.

## Enforcement

- **Protocol** (every runtime): `core/protocol/command-contract.md` §3–§5, plus the
  conformance checklist the Supervisor audits against.
- **Hook** (Claude Code): `hooks/scripts/guard-command.sh`, a PreToolUse guard on
  `Skill|SlashCommand|Task`. An `/aidd:<name>` with no manifest row is denied with the
  nearest match; an `aidd-*` skill is allowed with a one-line reminder that skills are not
  commands. It degrades silently outside an AIDD repo, without a manifest, or on a payload
  it cannot parse — a guard must never break an unrelated session.
- **Tests**: `tests/commands.test.sh` asserts manifest ↔ `commands/` are 1:1 (no phantom
  rows, no missing ones), that the contract names all four skills as non-commands, and
  that the guard denies an unknown command while allowing a real one.

## Progress contract

The same hardening pass fixed the other half of the lifecycle — what the user *hears*.
`core/protocol/progress.md` defines one progress line per completed step:

```text
[<phase> <step>/<total>] <what happened> · <evidence pointer> · gates: <k>/<n> · rigor: <mode> · next: <step name>
```

Blocked and failed steps get a distinct fixed shape naming the reason and the remediation
the playbook prescribes. Agent-count/model/parallelism deliberation, re-litigated plans,
playbook restatements, and apologies are forbidden output: they belong in
`supervision/audit.log` and the phase report artifacts, which the Supervisor reads and the
PR body cites. Gate asks are the one place for prose, capped at five lines. Depth lives in
the dashboard — its **Recent progress** section replays the last progress lines from
change history (see [dashboard](dashboard.md)).
