#!/usr/bin/env bash
AIDD_VERSION="0.2.0"
# AIDD Delta universal installer.
# Vendors the portable core into ./.aidd/framework/, patches AGENTS.md (managed block),
# and seeds state — idempotently. Never touches your constitution, memory, learnings,
# state values, or changes/.
#
# Usage (inside the target repo):
#   /path/to/AIDD-Delta/install.sh
#   AIDD_SRC=/path/to/AIDD-Delta ./install.sh
#   curl -fsSL <raw-url>/install.sh | AIDD_SRC=/path/to/AIDD-Delta bash
set -euo pipefail

TARGET="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"

find_src() {
  if [ -n "${AIDD_SRC:-}" ] && [ -d "${AIDD_SRC}/core" ]; then
    echo "${AIDD_SRC}/core"; return
  fi
  if [ -n "${SCRIPT_DIR}" ] && [ -d "${SCRIPT_DIR}/core" ]; then
    echo "${SCRIPT_DIR}/core"; return
  fi
  echo ""
}

SRC="$(find_src)"
if [ -z "${SRC}" ]; then
  echo "error: cannot locate AIDD core/. Set AIDD_SRC=/path/to/AIDD-Delta checkout." >&2
  exit 1
fi

echo "AIDD Delta ${AIDD_VERSION} — installing into ${TARGET}"

# 1. Vendor the framework (fresh every run; user artifacts live outside framework/).
rm -rf "${TARGET}/.aidd/framework"
mkdir -p "${TARGET}/.aidd/framework"
for d in playbooks prompts roles protocol templates schemas scripts; do
  cp -R "${SRC}/${d}" "${TARGET}/.aidd/framework/${d}"
done
printf '%s\n' "${AIDD_VERSION}" > "${TARGET}/.aidd/framework/VERSION"

# 2. Seed user artifacts only when missing.
mkdir -p "${TARGET}/.aidd/changes/_archive"
[ -f "${TARGET}/.aidd/state.yaml" ] || {
  sed "s/^aidd_version: .*/aidd_version: \"${AIDD_VERSION}\"/" \
    "${SRC}/templates/state.yaml" > "${TARGET}/.aidd/state.yaml"
}
[ -f "${TARGET}/.aidd/memory.md" ]    || cp "${SRC}/templates/memory.md"    "${TARGET}/.aidd/memory.md"
[ -f "${TARGET}/.aidd/learnings.md" ] || cp "${SRC}/templates/learnings.md" "${TARGET}/.aidd/learnings.md"

# 3. AGENTS.md managed block (append-not-clobber; replace between markers on re-run).
AGENTS="${TARGET}/AGENTS.md"
BEGIN="<!-- AIDD:BEGIN"
if [ ! -f "${AGENTS}" ]; then
  cp "${SRC}/AGENTS.md" "${AGENTS}"
elif grep -q "${BEGIN}" "${AGENTS}"; then
  python3 - "${AGENTS}" "${SRC}/AGENTS.md" <<'PY'
import re
import sys

agents, block_src = sys.argv[1], sys.argv[2]
with open(agents, encoding='utf-8') as fh:
    text = fh.read()
with open(block_src, encoding='utf-8') as fh:
    block = fh.read().strip()
pattern = re.compile(r'<!-- AIDD:BEGIN.*?<!-- AIDD:END -->', re.S)
with open(agents, 'w', encoding='utf-8') as fh:
    fh.write(pattern.sub(lambda _match: block, text, count=1))
PY
else
  { printf '\n'; cat "${SRC}/AGENTS.md"; } >> "${AGENTS}"
fi

# 4. Validate seeded state.
python3 "${TARGET}/.aidd/framework/scripts/aidd-validate.py" \
  "${TARGET}/.aidd/framework/schemas/state.schema.json" "${TARGET}/.aidd/state.yaml"

echo "installed: .aidd/framework (v${AIDD_VERSION}), AGENTS.md managed block, state seeded"
echo "next: run the Master phase — Claude Code: /aidd:master · other CLIs: .aidd/framework/prompts/master.md"
