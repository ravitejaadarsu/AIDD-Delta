#!/usr/bin/env bash
# Dashboard renderer: substitutes state into the template, no marker left behind.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
mkdir -p tests/tmp
out="tests/tmp/dash-$$.html"
bash core/scripts/render-dashboard.sh \
  tests/fixtures/states/global-valid.yaml \
  tests/fixtures/states/change-valid-mid-construction.yaml \
  "${out}" >/dev/null || fail=1
grep -q 'ST-001' "${out}" || { echo "state not embedded"; fail=1; }
if grep -q '__AIDD_STATE_JSON__' "${out}"; then echo "marker not substituted"; fail=1; fi
python3 -c "import shutil, os; os.remove('${out}')" 2>/dev/null || true
exit "${fail}"
