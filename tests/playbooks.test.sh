#!/usr/bin/env bash
# Playbook conformance: the Layer-2 machinery must stay REFERENCED from the playbooks that
# execute it. The playbook is the sole executable phase contract (00-pipeline.md), so a step
# that exists only in a protocol/role file is unreachable — this suite fails instead of
# letting that pass silently. Grep-level assertions, in refs.test.sh style.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
fail=0

need() { # file, extended-regex, what-it-wires
  if ! grep -qE "$2" "$1"; then
    echo "FAIL: $1 no longer references $3 (/$2/)"
    fail=1
  fi
}

# Construction: monitoring per wave, interrogation/negotiation ladder, delta baseline.
C=core/playbooks/30-construction.md
need "${C}" 'roles/master-agent\.md'                "the Master Agent role"
need "${C}" 'mode: monitor'                         "Master Agent mode: monitor (per wave)"
need "${C}" 'roles/auditor\.md'                     "the Auditor role"
need "${C}" 'protocol/interrogation\.md'            "the interrogation protocol"
need "${C}" 'protocol/negotiation\.md'              "the negotiation protocol"
need "${C}" 'build-snapshot\.sh pre-construction'   "the pre-construction (pre-implementation) baseline"

# QA: monitoring per step batch, delta review, debate, tally, final audit ladder.
Q=core/playbooks/40-qa.md
need "${Q}" 'mode: monitor'                                 "Master Agent mode: monitor (per QA batch)"
need "${Q}" 'audit/monitoring/qa-review-batch\.md'          "the QA review-batch monitoring note"
need "${Q}" 'audit/monitoring/qa-test-batch\.md'            "the QA test-batch monitoring note"
need "${Q}" 'audit/monitoring/qa-verification-batch\.md'    "the QA verification-batch monitoring note"
need "${Q}" 'mode: delta'                                   "the delta reviewer dispatch"
need "${Q}" 'roles/tally\.md'                               "the Tally role"
need "${Q}" 'protocol/test-debate\.md'                      "the test-debate protocol"
need "${Q}" 'roles/test-engineer\.md'                       "the Test Engineer role"
need "${Q}" 'protocol/interrogation\.md'                    "the interrogation protocol"
need "${Q}" 'protocol/negotiation\.md'                      "the negotiation protocol"
need "${Q}" 'roles/supervisor\.md'                          "the Supervisor audit + adjudication"
need "${Q}" 'audit\.negotiation\.rulings'                   "the negotiation rulings state mirror"

# The Supervisor must be able to detect a missing dispatch: its checklists name the artifacts.
S=core/protocol/supervision.md
need "${S}" 'audit/monitoring/\*'       "per-wave monitoring notes (Construction checklist)"
need "${S}" 'audit/monitoring/qa-\*'    "per-batch monitoring notes (QA checklist)"

exit "${fail}"
