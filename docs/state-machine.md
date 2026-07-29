# State Machine Reference

Two YAML files, schema-enforced, human-editable. Canonical rules:
`core/protocol/state-protocol.md`; schemas: `core/schemas/`.

## Global — `.aidd/state.yaml`

registry only: `schema`, `aidd_version`, `default_mode`, `active_change`,
`constitution` (present|missing), `changes` (id → in_progress|done|abandoned).

## Per change — `.aidd/changes/<id>/state.yaml`

- `phase`: document → master → inception → construction → qa → delivery → retro → done
- `phase_status`: not_started · in_progress · awaiting_gate · blocked · complete
- `step`: free-text breadcrumb making resume exact
- `gates.<key>`: status (pending/awaiting/approved/revised/stale/aborted), artifact,
  artifact_sha256, approved_by (human|auto), at, notes
- `quality_gates`: nine mode-independent checks (see `core/protocol/gates.md`)
- `stories.<id>`: status/attempts/wave · `fix_loop` · `backflow_used` ·
  `supervision.<phase>` · `scores.<phase>` · `history[]` (append-only audit)

## Why two files

Parallel changes must never contend on one state file (OpenSpec-style locality).
The global file stays a tiny registry; each change owns its machine.

## Validation

`python3 .aidd/framework/scripts/aidd-validate.py <schema> <file>` — zero dependencies.
On Claude Code the plugin's PostToolUse hook validates every state write automatically.
