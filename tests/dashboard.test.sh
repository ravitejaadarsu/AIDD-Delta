#!/usr/bin/env bash
# Dashboard renderer: substitutes state into the template, no marker left behind.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
fail=0
mkdir -p tests/tmp
out="tests/tmp/dash-$$.html"
bash core/scripts/render-dashboard.sh \
  tests/fixtures/states/global-valid.yaml \
  tests/fixtures/states/change-valid-mid-construction.yaml \
  "${out}" >/dev/null || fail=1
grep -q 'ST-001' "${out}" || { echo "state not embedded"; fail=1; }
if grep -q '__AIDD_STATE_JSON__' "${out}"; then echo "marker not substituted"; fail=1; fi

# Recent progress section: rendered, populated from change history, newest first.
grep -q 'Recent progress' "${out}" || { echo "Recent progress section missing"; fail=1; }
grep -q 'id="prog"' "${out}" || { echo "Recent progress table missing"; fail=1; }
grep -q '"progress"' "${out}" || { echo "progress array not embedded"; fail=1; }
python3 - "${out}" <<'PY' || fail=1
import json, re, sys
html = open(sys.argv[1], encoding='utf-8').read()
data = json.loads(re.search(r'const DATA = (\{.*?\});', html, re.S).group(1))
rows = data.get('progress')
if not isinstance(rows, list) or not rows:
    print('progress array empty — history events not replayed')
    sys.exit(1)
if rows[0]['line'] != 'gate g1_prd approved by auto':
    print(f'progress not newest-first: {rows[0]}')
    sys.exit(1)
if {r['shape'] for r in rows} != {'plain'}:
    print('plain history events must not be marked as contract-shaped')
    sys.exit(1)
PY
python3 -c "import shutil, os; os.remove('${out}')" 2>/dev/null || true
exit "${fail}"
