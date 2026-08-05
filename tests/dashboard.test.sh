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
# ── Rigor & cost: the section cost-governance.md §10 and rigor-modes.md claim renders.
# change-valid-audit.yaml is the fixture that actually carries rigor, cost, determinism
# and escapes, so it is the one that proves the claim rather than assuming it.
rc="tests/tmp/dash-rc-$$.html"
bash core/scripts/render-dashboard.sh \
  tests/fixtures/states/global-valid.yaml \
  tests/fixtures/states/change-valid-audit.yaml \
  "${rc}" >/dev/null || fail=1
grep -q 'Rigor &amp; cost' "${rc}" || { echo "Rigor & cost section missing"; fail=1; }
grep -q 'id="rigorcost"' "${rc}" || { echo "Rigor & cost card missing"; fail=1; }
python3 - "${rc}" <<'PY' || fail=1
import json, re, sys
html = open(sys.argv[1], encoding='utf-8').read()
data = json.loads(re.search(r'const DATA = (\{.*?\});\n', html, re.S).group(1))
c = data['change']
problems = []
# The card reads straight off change state, so the state it reads must be embedded.
for block, field in (('rigor', 'mode'), ('cost', 'spent_tokens'), ('cost', 'budget_minutes'),
                     ('determinism', 'quarantined')):
    if field not in (c.get(block) or {}):
        problems.append(f'change.{block}.{field} not embedded for the Rigor & cost card')
if not c.get('escapes'):
    problems.append('change.escapes not embedded for the quarantine/escape counts')
# The card must never invent a zero for something unmeasured.
for token in ('not measured', 'not recorded'):
    if token not in html:
        problems.append(f'the card lost its {token!r} fallback')
if problems:
    print('\n'.join(problems))
    sys.exit(1)
PY

# ── Quality gates render in BOTH encodings, and an `na` shows the reason it must carry
# (protocol/gates.md §The `na` encoding). An object-form gate rendered as [object Object]
# would hide exactly the reason the protocol exists to make visible.
gr="tests/tmp/dash-gr-$$.html"
bash core/scripts/render-dashboard.sh \
  tests/fixtures/states/global-valid.yaml \
  tests/fixtures/states/change-valid-gate-reason.yaml \
  "${gr}" >/dev/null || fail=1
python3 - "${gr}" <<'PY' || fail=1
import json, re, sys
html = open(sys.argv[1], encoding='utf-8').read()
data = json.loads(re.search(r'const DATA = (\{.*?\});\n', html, re.S).group(1))
gates = data['change']['quality_gates']
problems = []
if gates.get('tests_green') != 'passed':
    problems.append('scalar-form gate not embedded verbatim')
skipped = gates.get('mutation_floor_met')
if not isinstance(skipped, dict) or skipped.get('reason') != 'rigor:fast':
    problems.append(f'object-form gate lost its reason: {skipped!r}')
if 'typeof v === "object"' not in html:
    problems.append('the gate renderer does not branch on the two encodings')
if '<th>Reason</th>' not in html:
    problems.append('the quality-gate table has no Reason column')
if problems:
    print('\n'.join(problems))
    sys.exit(1)
PY

python3 -c "
import os
for f in ('${out}', '${rc}', '${gr}'):
    try: os.remove(f)
    except OSError: pass" 2>/dev/null || true
exit "${fail}"
