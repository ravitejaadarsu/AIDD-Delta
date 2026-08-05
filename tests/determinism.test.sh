#!/usr/bin/env bash
# Determinism conformance: the protocol must state per-mode repeat counts, what agreement
# means, the retry ban, the quarantine rules, and all six nondeterminism sources WITH their
# discriminating checks; the evidence_reproduced gate must exist in the schema and the seed
# template; the E2E Verifier must carry the repeat duty; and 40-qa must carry the annotations
# with its 17 frozen step numbers unchanged. Grep-level assertions, in refs.test.sh style.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
fail=0

need() { # file, extended-regex, what-it-wires
  if ! grep -qE "$2" "$1"; then
    echo "FAIL: $1 no longer references $3 (/$2/)"
    fail=1
  fi
}

exists() { # file
  if [ ! -f "$1" ]; then
    echo "FAIL: missing $1"
    fail=1
  fi
}

D=core/protocol/determinism.md
T=core/templates/determinism-report.md
E=core/roles/e2e-verifier.md
Q=core/playbooks/40-qa.md

exists "${D}"
exists "${T}"
exists docs/determinism.md
exists docs/design/decisions/018-determinism-proof.md

# ── the rule, and which claims it binds
need "${D}" 'not trusted until'           "the reproduce-before-trust rule"
need "${D}" 'tests_green'                 "the full-suite gating claim"
need "${D}" 'clean-state E2E'             "the clean-state E2E gating claim"
need "${D}" 'fix-loop iteration'          "the fix-loop-closing test claim"

# ── per-mode repeat counts, all three modes, with the cost justification
need "${D}" '^## 2\. How many repeats, per rigor mode' "the per-mode repeat table"
need "${D}" '\*\*2 runs\*\*'              "the two-run requirement"
need "${D}" 'corroboration'               "the standard-mode E2E corroboration label"
need "${D}" 'evidence_reproduced: na., .reason: rigor:fast|reason: rigor:fast' \
                                          "the fast-mode na with its reason"
need "${D}" 'smallest number that can disagree' "the cost justification for two runs"
need "${D}" 'Three is not worth it'       "the cost justification against three runs"

# ── what agreement means, and the retry ban
need "${D}" 'identical exit code'         "the exit-code agreement condition"
need "${D}" 'test id . outcome|test-id . outcome' "the test-id outcome-map agreement condition"
need "${D}" 'present in one run and absent' "collection nondeterminism as a disagreement"
need "${D}" 'never a second chance|never a retry' "the repeat-is-not-a-retry rule"
need "${D}" 'forbidden'                   "the ban on re-running until green"

# ── the six nondeterminism sources, each with its discriminating check
for source in 'unseeded randomness' 'wall-clock' 'timezone' 'network' 'shared fixtures' \
              'test-order dependence' 'concurrency'; do
  need "${D}" "${source}" "the '${source}' nondeterminism source"
done
for check in 'fixed seed' 'TZ=UTC' 'offline' 'run the test alone|run the test \*\*alone\*\*' \
             'reverse order' 'parallelism 1'; do
  need "${D}" "${check}" "the '${check}' discriminating check"
done
need "${D}" 'must name the suspected source|MUST name the suspected source' \
                                          "the name-the-source requirement"
need "${D}" 'unknown'                     "the bounded unknown-source escape hatch"

# ── quarantine
need "${D}" '^## 5\. Quarantine'          "the quarantine section"
need "${D}" 'determinism-report'          "the determinism report as the quarantine record"
need "${D}" 'may NOT be used as evidence' "the not-evidence rule"
need "${D}" 'reverts to unproven'         "the AC reverting to unproven"
need "${D}" 'existing fix loop|EXISTING fix loop|existing.. fix loop' \
                                          "the reuse of the existing fix loop"
need "${D}" 'accepted'                    "the human acceptance disposition"
need "${D}" 'accepted_reason'             "the recorded acceptance reason"
need "${D}" 'supervision VIOLATION'       "the silently-green quarantined test as a violation"
need core/protocol/supervision.md 'quarantined' "the Supervisor's quarantine check"
need core/protocol/supervision.md 'determinism repeats present' \
                                          "the Supervisor's repeats-present check"

# ── the gate
need "${D}" '^## 6\. The .evidence_reproduced. quality gate' "the determinism gate section"
S=core/schemas/change-state.schema.json
need "${S}" '"evidence_reproduced": \{ "enum": \["pending", "passed", "failed", "na"\] \}' \
                                          "the evidence_reproduced gate in the schema"
need "${S}" '"determinism": \{'           "the determinism object in the schema"
need "${S}" '"shared-fixture"'            "the suspected-source enum in the schema"
need core/templates/change-state.yaml '^  evidence_reproduced: pending' \
                                          "the seeded evidence_reproduced gate"
need core/templates/change-state.yaml '^determinism:' "the seeded determinism block"

# ── the E2E Verifier performs the repeats and writes the report
need "${E}" 'protocol/determinism\.md'    "the determinism protocol in the E2E Verifier"
need "${E}" 'twice'                       "the repeat duty"
need "${E}" 'never a retry'               "the retry ban in the role"
need "${E}" 'determinism-report\.md'      "the determinism report in the role's outputs"
need "${E}" 'quarantin'                   "the quarantine duty"

# ── the report template's columns
for col in 'suspected source' 'disposition' 'ACs affected'; do
  need "${T}" "${col}" "the report's '${col}' column"
done
need "${T}" 'QUARANTINED'                 "the QUARANTINED (never PASS) marking"
need "${T}" 'reverse order'               "the discriminating-check columns"

# ── 40-qa annotations, and the FROZEN 17-step numbering
need "${Q}" 'protocol/determinism\.md'    "QA's determinism annotations"
need "${Q}" 'evidence_reproduced'         "the determinism gate in QA"
need "${Q}" 'determinism-report\.md'      "the determinism report in QA"
need "${Q}" 'QUARANTINED'                 "the AC-matrix quarantine rule"
need core/playbooks/00-pipeline.md 'protocol/determinism\.md' "the pipeline's determinism duties"

steps=$(grep -cE '^1?[0-9]\. \*\*|^1?[0-9]\. Orchestrator' "${Q}")
if [ "${steps}" -ne 17 ]; then
  echo "FAIL: ${Q} must keep exactly 17 numbered steps (found ${steps})"
  fail=1
fi
# The frozen numbers themselves: 1..17, each exactly once, in order.
numbers=$(grep -oE '^1?[0-9]\. (\*\*|Orchestrator)' "${Q}" | grep -oE '^1?[0-9]' | tr '\n' ' ')
if [ "${numbers}" != "1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 " ]; then
  echo "FAIL: ${Q} step numbering changed (found: ${numbers})"
  fail=1
fi

exit "${fail}"
