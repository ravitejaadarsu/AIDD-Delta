#!/usr/bin/env bash
# Hook script unit tests with fixture stdin payloads.
set -uo pipefail
cd "$(dirname "$0")/.."
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
  cd "${TMP}"
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

exit "${fail}"
