#!/usr/bin/env bash
# Rigor-mode + deterministic-dispatch conformance: the protocol files must exist and state
# the classifier's critical-path triggers, every playbook step rigor affects must carry a
# `Rigor:` annotation (a reduction nobody can read is a silent skip), dispatch.md must carry
# a decision table covering all four phases, and the schema must accept a valid rigor block
# while rejecting an invalid mode. Grep-level assertions, in refs.test.sh style.
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

R=core/protocol/rigor-modes.md
D=core/protocol/dispatch.md

exists "${R}"
exists "${D}"
exists docs/rigor-modes.md
exists commands/rigor.md
exists docs/design/decisions/010-rigor-modes.md
exists docs/design/decisions/011-deterministic-dispatch.md

# The three modes, and the orthogonality that keeps them out of the autonomy modes' way.
need "${R}" '^### .fast.$'                "the fast mode section"
need "${R}" '^### .standard.$'            "the standard mode section"
need "${R}" '^### .critical.$'            "the critical mode section"
need "${R}" 'autonomy-modes\.md'          "the autonomy-mode orthogonality note"

# The classifier's critical-path triggers: every class the owner named must be stated.
for trigger in 'authn' 'authz' 'secrets' 'crypto' 'billing' 'pricing' \
               'tenant' 'migration' 'PII' 'public API' 'concurrency' 'locking' \
               'infra' 'deploy'; do
  need "${R}" "${trigger}" "the '${trigger}' critical-class trigger"
done
need "${R}" 'risk: critical'              "the story-level risk:critical marker trigger"
need "${R}" 'Path-pattern hints'          "the mechanically-matched path-pattern table"

# Selection, escalation, floor, override.
need "${R}" 'one-way'                     "one-way escalation"
need "${R}" 'Back-fill table'             "the escalation back-fill table"
need "${R}" 'floor'                       "the inviolable floor"
need "${R}" '/aidd:rigor'                 "the human override command"
need "${R}" 'reason: rigor:'              "the na-with-reason recording rule"

# Dispatch: a decision table covering all four phases, plus the rules that make it binding.
need "${D}" '## Decision table'           "the dispatch decision table"
need "${D}" '^\| Inception'               "Inception rows in the decision table"
need "${D}" '^\| Construction'            "Construction rows in the decision table"
need "${D}" '^\| QA'                      "QA rows in the decision table"
need "${D}" '^\| Delivery'                "Delivery rows in the decision table"
need "${D}" 'pairwise disjoint'           "the mechanical disjointness ownership rule"
need "${D}" 'Never re-decide'             "the never-re-decide rule"
need "${D}" 'supervision VIOLATION'       "re-deciding as a supervision violation"
need "${D}" 'Batching rule'               "the cap/queue batching rule"
need "${D}" 'file-scope\.md'              "the file-scope ownership protocol"
need "${D}" '## Worked examples'          "the per-phase worked examples"

# Every playbook step a rigor mode reduces or skips must SAY so, inline, next to the step.
for f in core/playbooks/20-inception.md core/playbooks/30-construction.md \
         core/playbooks/40-qa.md; do
  need "${f}" 'protocol/rigor-modes\.md'  "the rigor-modes protocol"
  need "${f}" 'protocol/dispatch\.md'     "the dispatch protocol"
  need "${f}" '^ *Rigor: '                "per-step Rigor: annotations"
done

# QA is where rigor bites hardest: the reduced surfaces each need their annotation.
Q=core/playbooks/40-qa.md
for surface in 'correctness \+ spec-compliance' 'functional-happy-path, regression-compat' \
               '1 round per' 'e2e_verified' 'tally_reconciled: na' \
               'debate_complete: na'; do
  need "${Q}" "${surface}" "the rigor annotation for '${surface}'"
done

# The 17-step QA numbering is FROZEN: annotations are inserted, never a renumber.
steps=$(grep -cE '^1?[0-9]\. \*\*|^1?[0-9]\. Orchestrator' "${Q}")
if [ "${steps}" -ne 17 ]; then
  echo "FAIL: ${Q} must keep exactly 17 numbered steps (found ${steps})"
  fail=1
fi

# Schema: a valid rigor block validates; an invalid mode is rejected.
S=core/schemas/change-state.schema.json
F=tests/fixtures/states
if ! python3 core/scripts/aidd-validate.py "${S}" "${F}/change-valid-audit.yaml" >/dev/null 2>&1; then
  echo "FAIL: valid rigor block rejected (${F}/change-valid-audit.yaml)"
  python3 core/scripts/aidd-validate.py "${S}" "${F}/change-valid-audit.yaml" || true
  fail=1
fi
if python3 core/scripts/aidd-validate.py "${S}" "${F}/change-invalid-rigor-mode.yaml" >/dev/null 2>&1; then
  echo "FAIL: invalid rigor.mode accepted (${F}/change-invalid-rigor-mode.yaml)"
  fail=1
fi
if ! python3 core/scripts/aidd-validate.py "${S}" core/templates/change-state.yaml >/dev/null 2>&1; then
  echo "FAIL: seeded template does not validate with its rigor block"
  fail=1
fi
need core/templates/change-state.yaml '^ *mode: standard'      "the seeded standard rigor mode"
need core/templates/change-state.yaml '^ *selected_by: classifier' "the seeded classifier selector"

exit "${fail}"
