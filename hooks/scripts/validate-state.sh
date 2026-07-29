#!/usr/bin/env bash
# PostToolUse(Write|Edit): schema-validate any AIDD state file that was just written.
# Exit 2 feeds the error back to the model so it fixes the state before proceeding.
set -uo pipefail
payload="$(cat)"
file="$(printf '%s' "${payload}" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null || echo "")"
case "${file}" in
  */.aidd/state.yaml) schema="state.schema.json" ;;
  */.aidd/changes/*/state.yaml) schema="change-state.schema.json" ;;
  *) exit 0 ;;
esac
root="${file%/.aidd/*}"
fw="${root}/.aidd/framework"
[ -f "${fw}/scripts/aidd-validate.py" ] || exit 0
if ! python3 "${fw}/scripts/aidd-validate.py" "${fw}/schemas/${schema}" "${file}" >&2; then
  echo "AIDD state file failed schema validation — fix ${file} before proceeding (protocol/state-protocol.md rule 4)." >&2
  exit 2
fi
exit 0
