#!/usr/bin/env bash
# Hook script unit tests with fixture stdin payloads.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd)"
fail=0
TMP="tests/tmp/hooks-$$"
mkdir -p "${TMP}/.aidd/framework/scripts" "${TMP}/.aidd/framework/schemas" "${TMP}/.aidd/changes/2026-07-29-x"
cleanup() { python3 -c "import shutil; shutil.rmtree('${ROOT}/${TMP}', ignore_errors=True)"; }
trap cleanup EXIT

cp core/scripts/aidd-validate.py "${TMP}/.aidd/framework/scripts/"
cp core/schemas/*.json "${TMP}/.aidd/framework/schemas/"
cp tests/fixtures/states/global-valid.yaml "${TMP}/.aidd/state.yaml"
cp tests/fixtures/states/change-invalid-bad-phase.yaml "${TMP}/.aidd/changes/2026-07-29-x/state.yaml"

payload() { printf '{"tool_input": {"file_path": "%s"}}' "$1"; }

# hooks.json: snapshot wrapper registered on Stop, alongside gate-check
grep -q 'build-snapshot.sh' hooks/hooks.json || { echo "hooks.json missing build-snapshot.sh registration"; fail=1; }

# hooks.json: guard-command registered as a PreToolUse guard on the command/skill surface
python3 - <<'PY' || fail=1
import json, sys
hooks = json.load(open('hooks/hooks.json', encoding='utf-8'))
errors = []
entries = [e for e in hooks['hooks'].get('PreToolUse', [])
           if any('guard-command.sh' in h['command'] for h in e['hooks'])]
if not entries:
    errors.append('hooks.json: guard-command.sh not registered on PreToolUse')
for e in entries:
    matcher = e.get('matcher', '')
    for tool in ('Skill', 'SlashCommand', 'Task'):
        if tool not in matcher:
            errors.append(f'guard-command matcher {matcher!r} does not cover {tool}')
if errors:
    print('\n'.join(errors))
    sys.exit(1)
PY

# guard-command: allows an aidd skill with a note; denies an unknown /aidd: command
(
  cd "${TMP}" || exit 1
  mkdir -p .aidd/framework/scripts
  cp "${ROOT}/core/scripts/aidd-commands.txt" .aidd/framework/scripts/
  note="$(printf '{"tool_name":"Skill","tool_input":{"skill":"aidd-supervision"}}' \
    | bash "${ROOT}/hooks/scripts/guard-command.sh" 2>&1)"
  [ $? -eq 0 ] || { echo "guard-command denied a legitimate skill"; exit 1; }
  echo "${note}" | grep -qi 'not a command' \
    || { echo "guard-command omitted the skills-are-not-commands note"; exit 1; }
  printf '{"tool_name":"SlashCommand","tool_input":{"command":"/aidd:aidd-qa"}}' \
    | bash "${ROOT}/hooks/scripts/guard-command.sh" >/dev/null 2>&1
  [ $? -eq 2 ] || { echo "guard-command allowed an unknown /aidd: command"; exit 1; }
  exit 0
) || fail=1

# validate-state: valid global state -> exit 0
payload "${ROOT}/${TMP}/.aidd/state.yaml" | bash hooks/scripts/validate-state.sh >/dev/null 2>&1
[ $? -eq 0 ] || { echo "validate-state rejected a valid state"; fail=1; }
# validate-state: invalid change state -> exit 2
payload "${ROOT}/${TMP}/.aidd/changes/2026-07-29-x/state.yaml" | bash hooks/scripts/validate-state.sh >/dev/null 2>&1
[ $? -eq 2 ] || { echo "validate-state accepted an invalid state"; fail=1; }
# validate-state: unrelated file -> exit 0
payload "/tmp/whatever.txt" | bash hooks/scripts/validate-state.sh >/dev/null 2>&1
[ $? -eq 0 ] || { echo "validate-state fired on unrelated file"; fail=1; }

# guard-scope: vendored framework write -> exit 2; normal file -> exit 0
payload "/x/.aidd/framework/playbooks/00-pipeline.md" | bash hooks/scripts/guard-scope.sh >/dev/null 2>&1
[ $? -eq 2 ] || { echo "guard-scope allowed a framework write"; fail=1; }
payload "/x/src/app.py" | bash hooks/scripts/guard-scope.sh >/dev/null 2>&1
[ $? -eq 0 ] || { echo "guard-scope blocked a normal write"; fail=1; }

# session-log: appends a dispatch line when a change is active
(
  cd "${TMP}" || exit 1
  python3 - <<'PY'
with open('.aidd/state.yaml', encoding='utf-8') as fh:
    src = fh.read()
with open('.aidd/state.yaml', 'w', encoding='utf-8') as fh:
    fh.write(src.replace('active_change: null', 'active_change: 2026-07-29-x'))
PY
  printf '{"tool_input": {"subagent_type": "aidd-builder", "description": "build ST-001"}}' \
    | bash "${ROOT}/hooks/scripts/session-log.sh"
)
grep -q 'aidd-builder | build ST-001' "${TMP}/.aidd/changes/2026-07-29-x/supervision/audit.log" \
  || { echo "session-log did not append dispatch"; fail=1; }

# gate-check: awaiting_gate surfaces a message
(
  cd "${TMP}"
  cp "${ROOT}/tests/fixtures/states/change-valid-awaiting-gate.yaml" .aidd/changes/2026-07-29-x/state.yaml
  # fixture change_id differs from folder; gate-check only reads phase fields, so fine
  out="$(bash "${ROOT}/hooks/scripts/gate-check.sh")"
  echo "${out}" | grep -q 'awaiting a gate' || { echo "gate-check missed awaiting_gate"; exit 1; }
) || fail=1

# build-snapshot: silently no-ops outside an AIDD repo (no .aidd/ present)
(
  NOAIDD="$(mktemp -d)"
  trap 'rm -rf "${NOAIDD}"' EXIT
  cd "${NOAIDD}"
  bash "${ROOT}/hooks/scripts/build-snapshot.sh" >/dev/null 2>&1
  code=$?
  [ "${code}" -eq 0 ] || { echo "build-snapshot exited ${code} outside an AIDD repo"; exit 1; }
  [ -e "${NOAIDD}/.aidd" ] && { echo "build-snapshot created .aidd outside an AIDD repo"; exit 1; }
  exit 0
) || fail=1

# build-snapshot: .aidd/ present but no vendored script -> silent no-op, nothing written
(
  NOVENDOR="$(mktemp -d)"
  trap 'rm -rf "${NOVENDOR}"' EXIT
  cd "${NOVENDOR}" || exit 1
  git init -q .
  mkdir -p .aidd
  bash "${ROOT}/hooks/scripts/build-snapshot.sh" >/dev/null 2>&1
  code=$?
  [ "${code}" -eq 0 ] || { echo "build-snapshot exited ${code} with .aidd but no vendored script"; exit 1; }
  [ -e "${NOVENDOR}/.aidd/context" ] && { echo "build-snapshot created .aidd/context without a vendored script"; exit 1; }
  exit 0
) || fail=1

# build-snapshot: invokes the vendored script with tag session-stop when present
(
  SNAP="$(mktemp -d)"
  trap 'rm -rf "${SNAP}"' EXIT
  git -C "${SNAP}" init -q
  mkdir -p "${SNAP}/.aidd/framework/scripts"
  cp "${ROOT}/core/scripts/build-snapshot.sh" "${SNAP}/.aidd/framework/scripts/build-snapshot.sh"
  git -C "${SNAP}" add -A
  git -C "${SNAP}" -c user.email=t@t -c user.name=t commit -qm init
  ( cd "${SNAP}" && bash "${ROOT}/hooks/scripts/build-snapshot.sh" >/dev/null 2>&1 )
  grep -q 'session-stop' "${SNAP}/.aidd/context/snapshot.md" \
    || { echo "build-snapshot did not tag the run session-stop"; exit 1; }
) || fail=1

exit "${fail}"
