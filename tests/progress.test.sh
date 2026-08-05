#!/usr/bin/env bash
# Progress contract: protocol/progress.md pins the exact line format, the forbidden-output
# rules and the gate-prompt cap; the dashboard renderer replays progress lines.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd)"
fail=0
P=core/protocol/progress.md

[ -f "${P}" ] || { echo "missing progress contract: ${P}"; exit 1; }

need() { # literal token, what it pins
  if ! grep -qF -- "$1" "${P}"; then
    echo "FAIL: ${P} does not pin $2 (missing literal: $1)"
    fail=1
  fi
}

# ── the exact line format, token by token
need '[<phase> <step>/<total>] <what happened> · <evidence pointer> · gates: <k>/<n> · rigor: <mode> · next: <step name>' \
     "the progress line format"
need 'gates: <k>/<n>'   "the gates field"
need 'rigor: <mode>'    "the rigor field"
need 'next: <step name>' "the next-step field"
need 'rigor: -'         "printing '-' when rigor.mode is absent"
need ' · '              "the field separator"
need 'One line per completed step' "one-line-per-step"

# ── blocked/failed shape, distinct and remediation-bearing
need '[<phase> <step>/<total>] BLOCKED: <reason> · remediation: <what the playbook prescribes> · evidence: <path> · next: <what unblocks it>' \
     "the blocked line shape"
need 'FAILED' "the failed variant"
need 'blocked_reason' "the blocked_reason source of truth"

# ── forbidden output
need 'Forbidden output' "the forbidden-output section"
for t in "how many agents" "which model" "parallelize" "Re-litigating" \
         "Restating the playbook" "Apologies" "did not change state"; do
  need "${t}" "a forbidden-output rule"
done

# ── deliberation destinations
need 'supervision/audit.log' "the audit log as the deliberation destination"

# ── gate prompts are the one place for prose, capped
need 'five lines' "the gate-prompt cap"
grep -qF 'the decision requested' "${P}" || { echo "FAIL: gate ask must request a decision"; fail=1; }
grep -qF 'the artifact path' "${P}"      || { echo "FAIL: gate ask must name the artifact path"; fail=1; }

# ── the dashboard is the detail surface
need 'Recent progress' "the dashboard as the detail surface"

# ── renderer emits the Recent progress section from change history
TMP="tests/tmp/progress-$$"
mkdir -p "${TMP}"
cleanup() { python3 -c "import shutil; shutil.rmtree('${ROOT}/${TMP}', ignore_errors=True)"; }
trap cleanup EXIT

python3 - "${TMP}" <<'PY'
import sys
tmp = sys.argv[1]
with open('tests/fixtures/states/change-valid-mid-construction.yaml', encoding='utf-8') as fh:
    src = fh.read()
line = ('[construction 4/9] ST-002 red tests written · '
        'changes/2026-07-29-user-auth/stories/ST-002.md · gates: 2/4 · rigor: - · '
        'next: ST-002 implementation')
entry = f'  - at: "2026-07-29T16:20:00Z"\n    event: "{line}"\n'
src = src.replace('updated_at:', entry + 'updated_at:', 1)
with open(f'{tmp}/change.yaml', 'w', encoding='utf-8') as fh:
    fh.write(src)
PY

out="${TMP}/dash.html"
bash core/scripts/render-dashboard.sh \
  tests/fixtures/states/global-valid.yaml "${TMP}/change.yaml" "${out}" >/dev/null \
  || { echo "renderer failed with a progress-bearing history"; fail=1; }
grep -q 'Recent progress' "${out}" || { echo "dashboard lacks the Recent progress section"; fail=1; }
grep -q 'ST-002 red tests written' "${out}" || { echo "progress line not rendered"; fail=1; }
grep -q '"progress"' "${out}" || { echo "renderer did not embed a progress array"; fail=1; }
grep -q '"shape": "contract"' "${out}" || { echo "renderer did not recognize the contract line shape"; fail=1; }
if grep -q '__AIDD_STATE_JSON__' "${out}"; then echo "marker not substituted"; fail=1; fi
grep -q 'no progress lines recorded yet' core/templates/dashboard.html \
  || { echo "template lacks an empty-progress fallback"; fail=1; }

# a state with no history still renders (empty progress array, no crash)
bash core/scripts/render-dashboard.sh \
  tests/fixtures/states/global-valid.yaml - "${TMP}/empty.html" >/dev/null \
  || { echo "renderer failed with no active change"; fail=1; }
grep -q '"progress": \[\]' "${TMP}/empty.html" || { echo "empty progress array not emitted"; fail=1; }

exit "${fail}"
