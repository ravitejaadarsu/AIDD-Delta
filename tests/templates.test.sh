#!/usr/bin/env bash
# Template contract tests: YAML seed templates and the story template must be schema-valid.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
S=core/schemas
T=core/templates
fail=0

check() {
  if ! "$@" >/dev/null 2>&1; then
    echo "template validation failed: $*"
    "$@" || true
    fail=1
  fi
}

check python3 core/scripts/aidd-validate.py "${S}/state.schema.json" "${T}/state.yaml"
check python3 core/scripts/aidd-validate.py "${S}/change-state.schema.json" "${T}/change-state.yaml"
check python3 core/scripts/aidd-validate.py --frontmatter "${S}/story-frontmatter.schema.json" "${T}/story.md"

# Every template the playbooks reference must exist.
for f in constitution.md memory.md learnings.md state.yaml change-state.yaml intent.md \
         prd.md architecture.md arch-candidate.md judge-scorecard.md epic.md story.md \
         mined-spec.md pre-review-findings.md qa-findings.md verification-report.md \
         security-report.md ac-matrix.md evidence-manifest.md playwright-capture.mjs \
         bench-capture.sh supervision-report.md dashboard.html traceability.mmd \
         pr-description.md ci-workflow.yml snapshot.md quality-baseline.md \
         context-delta.md interrogation-challenge.md interrogation-response.md \
         auditor-verdict.md negotiation-log.md monitoring-report.md tally.md \
         debate-record.md cost-ledger.md determinism-report.md escape-report.md \
         escape-register.md; do
  if [ ! -f "${T}/${f}" ]; then
    echo "missing template: ${T}/${f}"
    fail=1
  fi
done

# The dashboard template must carry the substitution marker exactly once.
count=$(grep -c "__AIDD_STATE_JSON__" "${T}/dashboard.html" || true)
if [ "${count}" -ne 1 ]; then
  echo "dashboard.html must contain __AIDD_STATE_JSON__ exactly once (found ${count})"
  fail=1
fi

exit "${fail}"
