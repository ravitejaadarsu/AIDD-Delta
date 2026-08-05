#!/usr/bin/env bash
# Cost-governance conformance: the protocol must state all three thresholds with distinct
# behavior and the exact projection formula, the within_cost_budget gate must exist in the
# schema and the seed template, the anti-gaming rule (no `na` for cost) must be stated and
# Supervisor-checkable, the ledger template must carry the documented columns, and
# aidd-cost.sh must actually summarize a synthetic ledger with a projection.
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

C=core/protocol/cost-governance.md
L=core/templates/cost-ledger.md
SH=core/scripts/aidd-cost.sh

exists "${C}"
exists "${L}"
exists "${SH}"
exists docs/cost-governance.md
exists commands/cost.md
exists docs/design/decisions/016-cost-governance.md

# ── the budget: concrete default numbers per rigor mode, declared tunable
need "${C}" '^## 1\. The budget'          "the per-change budget section"
need "${C}" 'budget_tokens'               "the token ceiling field"
need "${C}" 'budget_minutes'              "the wall-clock ceiling field"
need "${C}" '1,600,000'                   "the fast-mode default token ceiling"
need "${C}" '3,400,000'                   "the standard-mode default token ceiling"
need "${C}" '5,600,000'                   "the critical-mode default token ceiling"
need "${C}" 'constitution\.md'            "the tunability of the defaults"
need "${C}" 'derived, not measured|not measured, by exactly this formula|seeds, not measurements' \
                                          "the honest framing of the derived defaults"

# ── state fields, all seven, as the closed object
for field in 'budget_tokens' 'budget_minutes' 'spent_tokens' 'spent_minutes' 'by_phase' \
             'projection_tokens' 'stops'; do
  need "${C}" "${field}" "the cost.${field} state field"
done

# ── recording duty: one row per dispatch, never a zero for an unmeasured runtime
need "${C}" '^## 3\. Recording duty'      "the per-dispatch recording duty"
need "${C}" 'not measured'                "the not-measured recording rule"
need "${C}" 'Never a zero'                "the never-a-zero rule"
need "${C}" 'append-only'                 "the append-only ledger rule"

# ── the projection formula must be STATED, deterministically
need "${C}" '^## 4\. Projection'          "the projection section"
need "${C}" 'projection_tokens = spent_tokens \+' "the projection formula"
need "${C}" 'median_tokens\(c\)'          "the per-class median term"
need "${C}" 'floored to an integer'       "the deterministic tie rule"
need "${C}" 'lower bound'                 "the lower-bound reporting of unknown classes"
need "${C}" 'no smoothing, no weighting, no' "the no-model guarantee"

# ── three thresholds, each with a DISTINCT behavior
need "${C}" '\*\*soft\*\*'                "the soft threshold"
need "${C}" '\*\*hard\*\*'                "the hard threshold"
need "${C}" '\*\*runaway\*\*'             "the runaway threshold"
need "${C}" '### soft — report, do not stop'      "the soft behavior (report only)"
need "${C}" '### hard — STOP and ask'             "the hard behavior (stop and ask)"
need "${C}" '### runaway — abort the dispatch'    "the runaway behavior (abort, no retry)"
need "${C}" 'never silently retry|Never silently retry|never retrying silently' \
                                          "the no-silent-retry rule"
for disposition in 'raised' 'reduced-breadth' 'narrowed-scope' 'aborted'; do
  need "${C}" "${disposition}" "the '${disposition}' hard-stop disposition"
done
need "${C}" 'both autonomy modes'         "the forced-human hard stop in both autonomy modes"
need "${C}" 'progress\.md'                "the fixed progress-line format it must not extend"

# ── the floor is never traded for budget
need "${C}" '^## 6\. Cost never overrides the floor' "the floor-is-inviolable section"
for floor in 'TDD' 'Supervisor' 'Critic'; do
  need "${C}" "${floor}" "the ${floor} floor item"
done

# ── anti-gaming: an na justified by cost is forbidden, and the Supervisor checks it
need "${C}" '^## 8\. Anti-gaming'         "the anti-gaming section"
need "${C}" 'na. justified by cost is forbidden' "the forbidden cost-justified na"
need "${C}" 'reason: rigor:'              "the only legitimate na reason vocabulary"
need core/protocol/supervision.md 'No .na. justified by cost' \
                                          "the Supervisor's cost-na check"
need core/protocol/supervision.md 'cost/ledger\.md' "the Supervisor's ledger-present check"
need core/protocol/supervision.md 'cost\.by_phase'  "the Supervisor's ledger/state consistency check"

# ── the gate
need "${C}" 'within_cost_budget'          "the cost quality gate"
need "${C}" 'cost:no-dispatches'          "the single legitimate na reason for the cost gate"
S=core/schemas/change-state.schema.json
need "${S}" '"within_cost_budget": \{ "enum": \["pending", "passed", "failed", "na"\] \}' \
                                          "the within_cost_budget gate in the schema"
need "${S}" '"cost": \{'                  "the cost object in the schema"
need "${S}" '"aborted-dispatch"'          "the runaway disposition in the schema enum"
need core/templates/change-state.yaml '^  within_cost_budget: pending' \
                                          "the seeded within_cost_budget gate"
need core/templates/change-state.yaml '^cost:' "the seeded cost block"

# ── playbook wiring
need core/playbooks/00-pipeline.md 'protocol/cost-governance\.md' "the pipeline's cost duties"
need core/playbooks/40-qa.md       'protocol/cost-governance\.md' "QA's cost annotations"
need core/playbooks/50-delivery.md 'aidd-cost\.sh'               "the PR body's cost summary"
need core/playbooks/50-delivery.md 'Reversibility'               "the delivery reversibility note"

# ── the ledger template's documented columns
for col in 'at' 'phase' 'step' 'role' 'unit' 'tokens_in' 'tokens_out' 'minutes' \
           'cum_tokens' 'cum_minutes' 'source'; do
  need "${L}" "\| ${col} \|" "the ledger '${col}' column"
done
need "${L}" '^## Remaining planned dispatches' "the remaining-dispatch section the projection reads"
need "${L}" '^## Stops'                        "the stops section"
need "${L}" 'not measured'                     "the not-measured convention"

# ── the script: --help exits 0, and a synthetic ledger yields a summary with a projection
if ! bash "${SH}" --help >/dev/null 2>&1; then
  echo "FAIL: ${SH} --help did not exit 0"
  fail=1
fi
if bash "${SH}" --not-an-option >/dev/null 2>&1; then
  echo "FAIL: ${SH} accepted an unknown option"
  fail=1
fi

TMP="tests/tmp/cost-$$"
mkdir -p "${TMP}"
cleanup() { rm -rf "${TMP}"; }
trap cleanup EXIT

{
  echo '# Cost Ledger — 2026-08-06-synthetic'
  echo
  echo '## Budget'
  echo
  echo '| field | value |'
  echo '|---|---|'
  echo '| rigor_mode | standard |'
  echo '| budget_tokens | 150000 |'
  echo '| budget_minutes | 20 |'
  echo
  echo '## Dispatches'
  echo
  echo '| at | phase | step | role | unit | tokens_in | tokens_out | minutes | cum_tokens | cum_minutes | source |'
  echo '|---|---|---|---|---|---|---|---|---|---|---|'
  echo '| 2026-08-06T10:00:00Z | qa | QA 5 | test-engineer | api-contract | 30000 | 6000 | 2.0 | 36000 | 2.0 | measured |'
  echo '| 2026-08-06T10:02:00Z | qa | QA 5 | test-engineer | boundary-edge | 28000 | 5000 | 1.5 | 69000 | 3.5 | measured |'
  echo '| 2026-08-06T10:04:00Z | qa | QA 5 | test-engineer | functional-happy-path | 40000 | 8000 | 2.5 | 117000 | 6.0 | measured |'
  echo '| 2026-08-06T10:07:00Z | qa | QA 7 | e2e-verifier | - | not measured | not measured | 4.0 | 117000 | 10.0 | not measured |'
  echo
  echo '## Remaining planned dispatches'
  echo
  echo '| class | count |'
  echo '|---|---|'
  echo '| QA 5 | 2 |'
  echo '| QA 16 | 1 |'
  echo
  echo '## Stops'
  echo
  echo '| at | phase | threshold | reason | disposition |'
  echo '|---|---|---|---|---|'
  echo '| 2026-08-06T10:08:00Z | qa | soft | 70% of budget_tokens | pending |'
} > "${TMP}/ledger.md"

out="$(bash "${SH}" --ledger "${TMP}/ledger.md" 2>&1)"
if [ -z "${out}" ]; then
  echo "FAIL: ${SH} printed no summary for a synthetic ledger"
  fail=1
fi
say() { # extended-regex, what the summary must report
  if ! printf '%s\n' "${out}" | grep -qE "$1"; then
    echo "FAIL: ${SH} summary does not report $2 (/$1/)"
    fail=1
  fi
}
say 'rows: 4 \(measured 3, not measured 1\)' "the measured/not-measured row split"
say 'spent: 117000 tokens'                   "the spend recomputed from the ledger"
say 'budget: 150000 tokens'                  "the budget read from the ledger"
say 'QA 5: median 36000 tokens'              "the per-class median (measured rows only)"
say 'projection: >= 189000 tokens'           "the projection over the remaining plan"
say 'LOWER BOUND'                            "the lower-bound marker for an unknown class"
say 'status: (soft|hard)'                    "the threshold status"
say 'UNRESOLVED: 1 stop'                     "the unresolved pending stop"

# A measured-only ledger with every class known must print an exact projection, not a bound.
grep -v 'not measured' "${TMP}/ledger.md" | grep -v '^| QA 16' > "${TMP}/exact.md"
out2="$(bash "${SH}" --ledger "${TMP}/exact.md" 2>&1)"
if printf '%s\n' "${out2}" | grep -q 'LOWER BOUND'; then
  echo "FAIL: ${SH} reported a lower bound with every remaining class measured"
  fail=1
fi
if ! printf '%s\n' "${out2}" | grep -qE 'projection: 189000 tokens'; then
  echo "FAIL: ${SH} projection is not spent + count x class median (expected 189000)"
  printf '%s\n' "${out2}"
  fail=1
fi

# It must never write: the ledger it read is byte-identical afterwards.
before="$(cksum < "${TMP}/ledger.md")"
bash "${SH}" --ledger "${TMP}/ledger.md" >/dev/null 2>&1
after="$(cksum < "${TMP}/ledger.md")"
if [ "${before}" != "${after}" ]; then
  echo "FAIL: ${SH} modified the ledger it read (it must compute, never write)"
  fail=1
fi

exit "${fail}"
