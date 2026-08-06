#!/usr/bin/env bash
# PR-review conformance: the external-PR review standard is encoded mechanically, not
# culturally. Asserts the two-phase rule and the ban on solo-read verdicts, the mechanical
# different-agent routing rule, all three acceptance-bar verdicts with their PASS/FAIL/N/A
# requirement, the trace-the-consumer rule plus its worked example, the comment contract's
# literal forbidden list and file:line+side requirement, the no-post-without-approval rule
# citing jira-sync, the three roles and their thin wrappers, the templates' required columns
# and sections, the dispatch rows, and the command manifest agreeing across all four
# surfaces. Grep-level assertions, in escape.test.sh style.
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

P=core/protocol/pr-review.md
RF=core/roles/pr-file-reviewer.md
RX=core/roles/pr-cross-cutting-reviewer.md
RC=core/roles/pr-comment-validator.md
AF=agents/aidd-pr-file-reviewer.md
AX=agents/aidd-pr-cross-cutting-reviewer.md
AC=agents/aidd-pr-comment-validator.md
TF=core/templates/pr-review-findings.md
TR=core/templates/pr-review-report.md
TC=core/templates/pr-comments.md
D=core/protocol/dispatch.md
V=core/roles/adversarial-verifier.md

for f in "${P}" "${RF}" "${RX}" "${RC}" "${AF}" "${AX}" "${AC}" "${TF}" "${TR}" "${TC}" \
         commands/review-pr.md docs/pr-review.md docs/design/decisions/019-pr-review.md; do
  exists "${f}"
done

# ── 1. Two-phase, and a solo read never produces a verdict
need "${P}" 'Two-phase'                     "the two-phase rule"
need "${P}" 'solo read'                     "the ban on a solo-read verdict"
need "${P}" 'single-pass read may not produce a review verdict' \
                                            "the explicit single-pass prohibition"
need "${P}" 'incomplete by format'          "the format rejection of a one-agent report"
need "${P}" '^## 4\. Phase 0'               "phase 0"
need "${P}" '^## 5\. Phase 1'               "phase 1"
need "${P}" '^## 6\. Phase 2'               "phase 2"
need "${P}" '^## 7\. Phase 3'               "phase 3"
need "${P}" '^## 8\. Phase 4'               "phase 4"

# ── 2. Ground truth from the source, never the PR description
need "${P}" 'never the PR description|never as ground truth|never as evidence' \
                                            "the PR-description-is-not-ground-truth rule"
need "${P}" 'git merge-base'                "the merge-base computation"
need "${P}" 'git show'                      "verification against the repo tree at HEAD"
need "${P}" 'az repos pr show'              "the Azure DevOps fetch command"
need "${P}" 'gh pr view'                    "the GitHub fetch command"
need "${P}" 'gh pr diff'                    "the GitHub diff command"
need "${P}" 'azure-devops'                  "the Azure DevOps platform value"
need "${P}" 'BASE.*HEAD|resolved BASE'      "the resolved base/head SHAs recorded as evidence"

# ── 3. Fan out per changed source file, with bundles, sweeps, and dimension specialists
need "${P}" 'One agent per changed source file' "the per-file fan-out"
need "${P}" 'Bundle a helper'               "bundling a helper with its component"
need "${P}" 'sweep'                         "the sweep agents for trivial and config changes"
need "${P}" 'Dimension specialists'         "the dimension specialists"
need "${P}" 'invariants_files'              "the repo invariants the finders judge against"
need "${P}" 'ticket'                        "the ticket intent"

# ── 4. Adversarial verification of EVERY finding, by a DIFFERENT agent (mechanical)
need "${P}" 'never verified by the agent that raised it' "the different-agent routing rule"
need "${P}" 'raised_by'                     "the raised_by field the routing rule keys on"
need "${P}" 'verified_by'                   "the verified_by field recorded on the plan line"
need "${P}" 'adversarial-verifier'          "the reuse of the existing verifier role"
need "${P}" 'Why is this a real problem'    "the verifier's why question"
need "${P}" 'When does it manifest'         "the verifier's when question"
need "${P}" 'REFUTE'                        "the refute duty"
need "${P}" 'Default to refuted when uncertain' "the default-to-refuted rule"
need "${P}" 'Only .*CONFIRMED.* findings reach the final report|Only CONFIRMED' \
                                            "the confirmed-only report rule"
need "${P}" 'Severity is set by the verifier' "verifier-owned severity"
need "${P}" 'supervision VIOLATION|supervision.md' "the violation when the plan breaks the rule"
need "${V}" '^## PR mode'                   "the verifier's PR-mode parameterization"
need "${V}" 'Default to refuted'            "default-to-refuted in the verifier role"
need "${V}" 'You set the severity|set the severity' "verifier-owned severity in the role"

# ── 5. Master cross-cutting agent
need "${P}" 'cross-cutting'                 "the cross-cutting phase"
need "${P}" 'Shared-package impact'         "shared-package impact on other consumers"
need "${P}" 'Platform-only violations'      "platform-only violations"
need "${P}" 'Dead or unreachable paths'     "dead/unreachable paths"
need "${P}" 'Constant drift'                "constant drift"
need "${P}" 'Missing cross-boundary tests'  "missing cross-boundary tests"
need "${P}" 'Dedup'                         "the dedup duty"

# ── 6. Comments-validation agent as the final gate
need "${P}" 'Factual accuracy'              "the factual-accuracy check"
need "${P}" 'No contradiction'              "the contradiction check against the feed"
need "${P}" 'Tone compliance'               "the tone check"
need "${P}" 'dropped, not softened'         "the drop-never-soften rule"

# ── 7. The standing acceptance bar: three verdicts, PASS | FAIL | N/A, proven not assumed
need "${P}" '^## 9\. The standing acceptance bar' "the acceptance-bar section"
need "${P}" 'PASS .{1,4}FAIL .{1,4}N/A'     "the PASS/FAIL/N-A verdict requirement"
need "${P}" '### 9\.1 Additive'             "the additive verdict"
need "${P}" '### 9\.2 Non-breaking'         "the non-breaking verdict"
need "${P}" '### 9\.3 No hardcodes'         "the no-hardcodes verdict"
need "${P}" 'A review missing any of the three verdicts' "the incomplete-by-format rule"
need "${P}" 'pure pass-through'             "the empty-target-set pass-through proof"
need "${P}" 'tracing the inactive path|trace the inactive path|Prove it by tracing' \
                                            "the inactive-path trace requirement"
need "${P}" 'deviceEnabled'                 "the metadata-flag example that is CORRECT"
need "${P}" 'entityType'                    "the entityType redline"
need "${P}" 'redline'                       "the redline vocabulary"
need "${P}" 'rg -n'                         "the ripgrep redline scan"
need "${P}" 'allowlist'                     "the framework allowlist check"
need "${P}" 'ts-ignore|escape hatches'      "the new-escape-hatch flag"
need "${P}" 'vacuous|verify real behavior'  "the honest vacuous-test assessment"
need "${P}" 'determinism\.md'               "the determinism cross-reference"
need "${P}" 'mocked-proof'                  "the mocked-proof defect class"

# ── 8. Trace the real consumer before flagging shared code, with the worked example
need "${P}" '^## 10\. Trace the real consumer' "the trace-the-consumer protocol step"
need "${P}" 'Worked example'                "the worked example"
need "${P}" 'safeCondition'                 "the shared evaluator in the worked example"
need "${P}" 'resolveCondition'              "the separate local evaluator in the worked example"
need "${P}" 'per consumer'                  "the per-consumer verdict rule"
need "${P}" 'importer'                      "the importer grep that proves the verdict"
need "${P}" 'mandatory' "the mandatory verifier question on shared/exported symbols"

# ── 9. Comment contract: forbidden phrases listed literally, file:line + side required
need "${P}" '^## 11\. Comment contract'     "the comment contract"
need "${P}" 'Not collegial'                 "the not-collegial tone rule"
need "${P}" 'hey <name>'                    "the forbidden greeting, literally"
need "${P}" 'I feel'                        "the forbidden 'I feel', literally"
need "${P}" 'I might be wrong here'         "the forbidden hedge, literally"
need "${P}" 'can we maybe'                  "the forbidden ask, literally"
need "${P}" 'just a nit but'                "the forbidden nit opener, literally"
need "${P}" 'emojis'                        "the emoji ban"
need "${P}" 'exclamation marks'             "the exclamation-mark ban"
need "${P}" 'closing ask'                   "the required closing ask"
need "${P}" 'before merge'                  "the imperative ask example"
need "${P}" 'file:line'                     "the file:line requirement"
need "${P}" 'not post-ready'                "the not-post-ready consequence"
need "${P}" 'right' "the right-side rule for added code"
need "${P}" 'left'  "the left-side rule for removed code"

# ── 10. Never post without explicit human approval, mirroring jira-sync write-back
need "${P}" '^## 12\. Posting'              "the posting section"
need "${P}" 'default OFF|OFF by default'    "posting defaulting to off"
need "${P}" 'explicit human approval'       "the explicit-approval requirement"
need "${P}" 'jira-sync\.md'                 "the jira-sync write-back precedent"
need "${P}" 'both autonomy modes'           "the rule holding in both autonomy modes"
need "${P}" 'Silence is not approval'       "the no-implicit-approval rule"
need commands/review-pr.md 'without explicit human approval|Nothing is posted' \
                                            "the command's no-post note"

# ── 11. Budgets per rigor mode, and the report the human actually sees
need "${P}" '^## 13\. Budgets per rigor mode' "the per-rigor-mode budgets"
need "${P}" 'rigor-modes\.md'               "the rigor-mode protocol"
need "${P}" 'progress\.md'                  "the progress contract for user-facing output"
need "${P}" 'Never raw agent dumps|never raw agent dumps' "the no-raw-dumps rule"

# ── 12. Configuration lives in the constitution, with working defaults
need "${P}" 'pr_review'                     "the constitution config block"
need "${P}" 'works with zero configuration' "the zero-config default"
need core/templates/constitution.md '^## PR review' "the constitution's PR-review section"
need core/templates/constitution.md 'pr_review:'    "the pr_review block in the constitution"
need core/templates/constitution.md 'post_comments: false' "posting defaulting to false"
need docs/pr-review.md 'Phoenix'            "the Phoenix worked example in the docs page"
need docs/pr-review.md 'isa-'               "the repo-specific agent roster in the example"
need docs/pr-review.md 'framework-allowlist' "the allowlist file in the example"
need docs/pr-review.md 'Canonical: .core/protocol/pr-review\.md' "the canonical pointer"

# ── 13. Roles + thin wrappers (the repo's three-file pattern)
for pair in "${RF}:pr-file-reviewer" "${RX}:pr-cross-cutting-reviewer" \
            "${RC}:pr-comment-validator"; do
  role_file="${pair%%:*}"
  role_name="${pair##*:}"
  need "${role_file}" "^role: ${role_name}$"  "the role key"
  need "${role_file}" '^stage_class: adjudicative$' "the adjudicative stage class"
  need "${role_file}" '^tools: '              "the tools line"
  need "${role_file}" 'never edits'           "the read-only constraint"
  for section in '^## Mission' '^## Inputs' '^## Protocol' '^## Self-verification' \
                 '^## Report format'; do
    need "${role_file}" "${section}" "the ${section#^## } section"
  done
done
for pair in "${AF}:pr-file-reviewer" "${AX}:pr-cross-cutting-reviewer" \
            "${AC}:pr-comment-validator"; do
  agent_file="${pair%%:*}"
  role_name="${pair##*:}"
  need "${agent_file}" "^name: aidd-${role_name}$" "the agent name"
  need "${agent_file}" '^description: '            "the agent description"
  need "${agent_file}" '^tools: '                  "the agent tool list"
  need "${agent_file}" "\.aidd/framework/roles/${role_name}\.md" "its vendored role file"
done
need "${RF}" 'git show'                      "the file reviewer reading the tree at HEAD"
need "${RF}" 'raised_by'                     "the file reviewer stamping raised_by"
need "${RX}" 'Constant drift'                "the cross-cutting agent's constant-drift duty"
need "${RC}" 'dropped, not softened|Dropped, not softened' "the validator's drop rule"
need "${RC}" 'not posted'                    "the validator never posting"

# ── 14. Templates carry their required columns and sections
need "${TF}" 'raised_by'                     "the raised_by column"
need "${TF}" 'file:line'                     "the file:line column"
need "${TF}" 'side'                          "the side column"
need "${TF}" 'Proposed severity'             "the proposed-severity column"
need "${TF}" 'Concrete scenario'             "the concrete-scenario column"
need "${TF}" '^## Consumer traces'           "the consumer-trace section"
need "${TF}" 'invalid by format'             "the format rejection of an unscenarioed finding"
need "${TR}" '^## Ground truth'              "the report's ground-truth header"
need "${TR}" 'BASE sha'                      "the resolved base sha"
need "${TR}" 'HEAD sha'                      "the resolved head sha"
need "${TR}" '^## Acceptance bar'            "the acceptance-bar section"
need "${TR}" 'Additive'                      "the additive row"
need "${TR}" 'Non-breaking'                  "the non-breaking row"
need "${TR}" 'No hardcodes'                  "the no-hardcodes row"
need "${TR}" 'PASS .{1,4}FAIL .{1,4}N/A'     "the PASS/FAIL/N-A cells"
need "${TR}" '^## Findings funnel'           "the findings funnel"
need "${TR}" 'Raised'                        "the raised count"
need "${TR}" 'CONFIRMED'                     "the confirmed count"
need "${TR}" 'REFUTED'                       "the refuted count"
need "${TR}" 'Severity .verifier.'           "the verifier-owned severity column"
need "${TR}" 'not posted'                    "the posting status"
need "${TC}" 'status: not posted'            "the not-posted status"
need "${TC}" 'Side'                          "the side column"
need "${TC}" '^## Dropped comments'          "the drop list"
need "${TC}" 'Failing check'                 "the failing-check column"
need "${TC}" 'hey <name>'                    "the literal forbidden greeting"
need "${TC}" 'I might be wrong here'         "the literal forbidden hedge"
for pair_no in 1 2 3; do
  need "${TC}" "^### Pair ${pair_no}" "example pair ${pair_no}"
done
need "${TC}" '^Bad:'                         "the bad example label"
need "${TC}" '^Good:'                        "the good example label"

# ── 15. Dispatch rows: classes, unit counts, caps, ownership, deterministic order
for class in 'pr1-file' 'pr1-sweep' 'pr1-dim' 'pr2-verify' 'pr3-cross' 'pr4-comments'; do
  need "${D}" "${class}" "the '${class}' dispatch row"
done
need "${D}" 'one per changed source file'    "the per-file unit count"
need "${D}" 'path asc'                       "the deterministic path order"
need "${D}" 'finding id asc'                 "the deterministic finding order"
need "${D}" 'artifact-disjoint'              "the per-file artifact-disjointness"
need "${D}" 'never verified by the agent that raised it' \
                                             "the routing rule in the dispatch table"
need "${D}" 'every finding / every finding / every finding' \
                                             "verification of every finding in all modes"

# ── 16. The command manifest agrees across all four surfaces
need commands/review-pr.md '\.aidd/framework/protocol/pr-review\.md' \
                                             "the command's bound protocol path"
need commands/review-pr.md '^description: '  "the command description frontmatter"
need core/scripts/aidd-commands.txt '^/aidd:review-pr\|\.aidd/framework/protocol/pr-review\.md\|' \
                                             "the /aidd:review-pr manifest row"
need core/protocol/command-contract.md '\| .\/aidd:review-pr. \| .\.aidd/framework/protocol/pr-review\.md. \|' \
                                             "the contract binding-table row"
need tests/manifest.test.sh 'expected 21 commands' "the bumped command count"
need tests/manifest.test.sh 'expected 29 agents'   "the bumped agent count"

# ── 17. Docs surface: capability-matrix row and the ADR
need docs/capability-matrix.md 'External PR review' "the capability-matrix row"
need docs/capability-matrix.md 'core/protocol/pr-review\.md' "the matrix row's canonical link"
need docs/design/decisions/019-pr-review.md '^# ADR 019' "the ADR heading"
need docs/design/decisions/019-pr-review.md '\*\*Decision\.\*\*'    "the ADR decision"
need docs/design/decisions/019-pr-review.md '\*\*Why\.\*\*'         "the ADR rationale"
need docs/design/decisions/019-pr-review.md '\*\*Consequence\.\*\*' "the ADR consequence"

exit "${fail}"
