#!/usr/bin/env bash
# Escape-analysis conformance: the role + its thin agent wrapper must exist with the repo's
# frontmatter shape, the protocol must demand the per-layer verdict table over ALL named
# layers with its four columns, both mandatory outputs, the proposals-are-never-auto-applied
# rule, the honest no-layer verdict, and the two metrics; and the EXISTING learning loop
# (learning.md, retro-learner.md, 60-retro.md) must carry the escape channel rather than a
# duplicate of it. Grep-level assertions, in refs.test.sh style.
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

E=core/protocol/escape-analysis.md
R=core/roles/escape-analyst.md
A=agents/aidd-escape-analyst.md
T=core/templates/escape-report.md

exists "${E}"
exists "${R}"
exists "${A}"
exists "${T}"
exists commands/escape.md
exists docs/escape-analysis.md
exists docs/design/decisions/017-escape-analysis.md

# ── role + wrapper frontmatter shape (the repo's three-file pattern)
need "${R}" '^role: escape-analyst$'      "the role key"
need "${R}" '^stage_class: adjudicative$' "the adjudicative stage class"
need "${R}" '^tools: '                    "the tools line"
need "${R}" 'never edits'                 "the read-only constraint"
for section in '^## Mission' '^## Inputs' '^## Protocol' '^## Self-verification' \
               '^## Report format'; do
  need "${R}" "${section}" "the ${section#^## } section"
done
need "${A}" '^name: aidd-escape-analyst$' "the agent name"
need "${A}" '^description: '              "the agent description"
need "${A}" '^tools: '                    "the agent tool list"
need "${A}" '\.aidd/framework/roles/escape-analyst\.md' "its vendored role file"

# ── trigger
need "${E}" '/aidd:escape'                "the escape command trigger"
need "${E}" 'merged'                      "the merged-change precondition"
need "${E}" 'out-of-scope'                "the honest no-AIDD-change attribution outcome"
need "${E}" 're-open'                     "the no-phase-re-open rule"

# ── the per-layer verdict table: every named layer, every column
for layer in 'L1-review' 'L1-tests' 'L2-auditor' 'L2-tally' 'L2-debate' 'L3-supervisor' \
             'critic' 'e2e-mutation' 'evidence-capture'; do
  need "${E}" "${layer}" "the '${layer}' verdict row"
  need "${T}" "${layer}" "the '${layer}' row in the report template"
done
for column in 'should_have_caught' 'did' 'why_missed' 'preventable_by'; do
  need "${E}" "${column}" "the '${column}' verdict column"
  need "${T}" "${column}" "the '${column}' column in the report template"
done
need "${E}" 'A row is never omitted'      "the all-rows-always rule"
need "${E}" 'by path'                     "the cite-the-blind-artifact-by-path rule"
need "${E}" 'rejected by format'          "the format rejection of vague cells"
need "${E}" 'caught-then-dropped|did: yes. is possible' \
                                          "the caught-then-dropped escape sub-class"

# ── the honest verdict, with its required cost argument
need "${E}" 'no-layer-at-reasonable-cost' "the no-layer-could-have-caught-it verdict"
need "${E}" 'legitimate'                  "that verdict being a legitimate outcome"
need "${E}" 'not a default'               "that verdict not being a default"

# ── two mandatory outputs
need "${E}" '^## 4\. Two mandatory outputs' "the mandatory-outputs section"
need "${E}" 'regression test'             "the mandatory regression test"
need "${E}" 'fails on the escaped defect and passes after the fix' \
                                          "the red-then-green regression requirement"
need "${E}" 'RED'                         "the observed-red evidence requirement"
need "${E}" 'amendment'                   "the protocol amendment proposal"
need "${E}" 'diff-level'                  "the diff-level specificity of the amendment"
need "${E}" 'learnings\.md'               "the amendment landing in learnings.md"

# ── amendments are proposals, never auto-applied
need "${E}" 'never applied automatically|never auto-applied' \
                                          "the proposals-are-not-auto-applied rule"
need "${E}" 'A human'                     "the human decision"
need "${R}" 'proposal'                    "the role's proposal-only amendment duty"
need "${A}" 'never edit'                  "the wrapper's never-edit-a-protocol-file rule"
need commands/escape.md 'never applied automatically|proposal' \
                                          "the command's proposal-only note"

# ── metrics: defined precisely, with the honest reporting rules
need "${E}" 'escape_rate ='               "the escape-rate definition"
need "${E}" 'blindness\(layer\) ='        "the layer-blindness definition"
need "${E}" 'numerator and the denominator|numerator and denominator' \
                                          "the print-both-terms rule"
need "${E}" 'not measured'                "the not-measured (never 0%) rule"
need "${E}" 'counter-metric'              "the counter-metric framing"
need "${E}" 'register\.md'                "the escape register"
# The register is referenced by six files, so it needs a template like every other artifact.
G=core/templates/escape-register.md
exists "${G}"
need "${E}" 'templates/escape-register\.md' "the register's template"
need "${G}" '^## Metrics'                 "the recomputed metrics section"
need "${G}" 'escape_rate|Escape rate'     "the escape-rate metric"
need "${G}" 'not measured'                "the not-measured (never 0%) rule in the template"
need "${G}" 'numerator and the denominator|numerator and denominator" *|numerator' \
                                          "the print-both-terms rule in the template"
for layer in 'L1-review' 'L1-tests' 'L2-auditor' 'L2-tally' 'L2-debate' 'L3-supervisor' \
             'critic' 'e2e-mutation' 'evidence-capture'; do
  need "${G}" "${layer}" "the '${layer}' blindness row in the register template"
done
need "${E}" 'bench/harness\.md'           "the shared defect-class vocabulary in bench/"

# ── repeats escalate rather than re-propose
need "${E}" 'repeat'                      "the repeat-escape rule"
need "${E}" 'repeat_of'                   "the repeat_of field"
need "${E}" 'Do not re-propose'           "the no-re-proposal rule"
need "${E}" 'escalate'                    "the human escalation of a repeat"

# ── the EXISTING learning loop is extended, not duplicated
L=core/protocol/learning.md
need "${L}" '## The escape channel'       "the escape channel in the learning protocol"
need "${L}" 'escape-analysis\.md'         "the escape protocol reference"
need "${L}" 'retro addendum'              "the retro addendum for an already-retro'd change"
need "${L}" 'Same file, same format, same dedupe' "the reuse of the existing lesson format"
need "${L}" 'repeat'                      "the repeat-escalation rule in learning"
need core/roles/retro-learner.md 'escape'         "the Retro Learner's escape inputs"
need core/roles/retro-learner.md 'retro addendum' "the Retro Learner's addendum duty"
need core/playbooks/60-retro.md 'protocol/escape-analysis\.md' "60-retro's escape channel"
need core/playbooks/60-retro.md 'roles/escape-analyst\.md'     "60-retro naming the Escape Analyst"
need core/playbooks/00-pipeline.md 'protocol/escape-analysis\.md' "the pipeline's escape duties"

# ── schema: the escapes array with its closed vocabularies
S=core/schemas/change-state.schema.json
need "${S}" '"escapes": \{'               "the escapes array in the schema"
need "${S}" '"defect_class"'              "the defect_class enum in the schema"
need "${S}" '"no-layer-at-reasonable-cost"' "the honest verdict in the schema enum"
need "${S}" '"evidence-capture"'          "the extended layer token in the schema enum"
need core/templates/change-state.yaml '^escapes: \[\]' "the seeded escapes array"

# ── the manifest binds the command to this protocol
need core/scripts/aidd-commands.txt '^/aidd:escape\|\.aidd/framework/protocol/escape-analysis\.md\|' \
                                          "the /aidd:escape manifest row"

exit "${fail}"
