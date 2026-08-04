#!/usr/bin/env bash
# Stop hook: refresh the gitignored .aidd/context/ snapshot pack after each session.
# Silent no-op outside an AIDD repo or without git; other runtimes rely on the
# orchestrator protocol duty to call core/scripts/build-snapshot.sh directly.
set -uo pipefail
[ -d ".aidd" ] || exit 0
command -v git >/dev/null 2>&1 || exit 0
script=".aidd/framework/scripts/build-snapshot.sh"
[ -f "${script}" ] || exit 0
bash "${script}" session-stop >/dev/null 2>&1
exit 0
