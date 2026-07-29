#!/usr/bin/env bash
# PreToolUse(Write|Edit): protect the vendored framework and enforce story file-scope.
# 1. Blocks edits under .aidd/framework/ (vendored copy — edit the AIDD-Delta repo instead).
# 2. During construction, blocks writes outside the union of in-progress story scopes
#    (belt-and-braces; the builder protocol is the primary control).
set -uo pipefail
payload="$(cat)"
file="$(printf '%s' "${payload}" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null || echo "")"
[ -n "${file}" ] || exit 0
case "${file}" in
  */.aidd/framework/*)
    echo "Blocked: ${file} is the vendored AIDD framework. Change the AIDD-Delta repo and reinstall (/aidd:upgrade)." >&2
    exit 2 ;;
esac
exit 0
