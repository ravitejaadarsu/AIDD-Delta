#!/usr/bin/env bash
# Installer contract: golden tree, idempotency, user-data preservation, AGENTS.md patching.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
fail=0
TMP="tests/tmp/install-$$"
mkdir -p "${TMP}/repo"
cleanup() { python3 -c "import shutil; shutil.rmtree('${ROOT}/${TMP}', ignore_errors=True)"; }
trap cleanup EXIT

# 1. Fresh install: golden tree.
( cd "${TMP}/repo" && bash "${ROOT}/install.sh" >/dev/null )
for p in .aidd/framework/VERSION .aidd/framework/playbooks/00-pipeline.md \
         .aidd/framework/roles/master-supervisor.md .aidd/framework/protocol/gates.md \
         .aidd/framework/templates/story.md .aidd/framework/schemas/change-state.schema.json \
         .aidd/framework/scripts/aidd-validate.py .aidd/framework/scripts/render-dashboard.sh \
         .aidd/state.yaml .aidd/memory.md .aidd/learnings.md .aidd/changes/_archive AGENTS.md; do
  [ -e "${TMP}/repo/${p}" ] || { echo "missing after install: ${p}"; fail=1; }
done
for d in playbooks prompts roles protocol templates schemas scripts; do
  if ! diff <(ls "core/${d}") <(ls "${TMP}/repo/.aidd/framework/${d}") >/dev/null; then
    echo "vendored ${d} differs from core/${d}"
    fail=1
  fi
done
grep -qxF '.aidd/context/' "${TMP}/repo/.gitignore" \
  || { echo ".gitignore missing .aidd/context/ after fresh install"; fail=1; }

# 2. Idempotency + user-data preservation.
python3 - "${TMP}/repo/.aidd/state.yaml" <<'PY'
import sys
p = sys.argv[1]
with open(p, encoding='utf-8') as fh:
    src = fh.read()
with open(p, 'w', encoding='utf-8') as fh:
    fh.write(src.replace('default_mode: let-me-look', 'default_mode: take-care'))
PY
( cd "${TMP}/repo" && bash "${ROOT}/install.sh" >/dev/null )
grep -q '^default_mode: take-care' "${TMP}/repo/.aidd/state.yaml" || { echo "state clobbered on reinstall"; fail=1; }
n=$(grep -c 'AIDD:BEGIN' "${TMP}/repo/AGENTS.md")
[ "${n}" -eq 1 ] || { echo "AGENTS block count wrong after reinstall (${n})"; fail=1; }
n=$(grep -cxF '.aidd/context/' "${TMP}/repo/.gitignore")
[ "${n}" -eq 1 ] || { echo "gitignore .aidd/context/ line duplicated on reinstall (${n})"; fail=1; }

# 3. Append-not-clobber on a pre-existing AGENTS.md; no duplication on re-run.
mkdir -p "${TMP}/repo2"
printf '# My rules\nkeep me\n' > "${TMP}/repo2/AGENTS.md"
( cd "${TMP}/repo2" && bash "${ROOT}/install.sh" >/dev/null )
grep -q 'keep me' "${TMP}/repo2/AGENTS.md" || { echo "existing AGENTS.md clobbered"; fail=1; }
grep -q 'AIDD:BEGIN' "${TMP}/repo2/AGENTS.md" || { echo "AIDD block not appended"; fail=1; }
( cd "${TMP}/repo2" && bash "${ROOT}/install.sh" >/dev/null )
n=$(grep -c 'AIDD:BEGIN' "${TMP}/repo2/AGENTS.md")
[ "${n}" -eq 1 ] || { echo "block duplicated on re-run (${n})"; fail=1; }

exit "${fail}"
