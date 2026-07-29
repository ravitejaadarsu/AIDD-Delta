#!/usr/bin/env bash
# PreToolUse(Task): append every subagent dispatch to the supervision audit log.
set -uo pipefail
payload="$(cat)"
[ -f ".aidd/state.yaml" ] || exit 0
active="$(grep -E '^active_change:' .aidd/state.yaml | awk '{print $2}')"
[ -n "${active}" ] && [ "${active}" != "null" ] || exit 0
dir=".aidd/changes/${active}/supervision"
mkdir -p "${dir}"
printf '%s' "${payload}" | python3 -c '
import datetime, json, sys
p = json.load(sys.stdin)
ti = p.get("tool_input", {})
desc = ti.get("description") or ti.get("prompt", "")[:80].replace("\n", " ")
agent = ti.get("subagent_type", "unknown")
ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
print(f"{ts} | dispatch | {agent} | {desc}")
' >> "${dir}/audit.log" 2>/dev/null || true
exit 0
