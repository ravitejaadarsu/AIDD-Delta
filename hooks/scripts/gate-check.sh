#!/usr/bin/env bash
# Stop hook: surface pending AIDD gates / mid-phase state so runs are not abandoned silently.
set -uo pipefail
state=".aidd/state.yaml"
[ -f "${state}" ] || exit 0
active="$(grep -E '^active_change:' "${state}" | awk '{print $2}')"
[ -n "${active}" ] && [ "${active}" != "null" ] || exit 0
cs=".aidd/changes/${active}/state.yaml"
[ -f "${cs}" ] || exit 0
status="$(grep -E '^phase_status:' "${cs}" | awk '{print $2}')"
phase="$(grep -E '^phase:' "${cs}" | awk '{print $2}')"
case "${status}" in
  awaiting_gate)
    echo "AIDD: change '${active}' is awaiting a gate in phase '${phase}'. Approve with /aidd:approve or send revisions with /aidd:revise." ;;
  in_progress)
    echo "AIDD: change '${active}' is mid-${phase}. Resume anytime with /aidd:resume." ;;
esac
exit 0
