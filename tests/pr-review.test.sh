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
need "${TF}" 'Concrete (failure )?scenario' "the concrete-scenario column"
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

# ── 17. The stack-detected specialist roster, probed and degraded (never silently)
need "${P}" '^## 15\. The specialist roster' "the specialist-roster section"
need "${P}" 'stack-detected'                 "stack detection as the resolution input"
for lens in typescript react vue python django fastapi go rust java kotlin swift cpp \
            csharp php fsharp flutter database security silent-failure type-design \
            test-quality comments a11y performance mle healthcare simplify; do
  need "${P}" "^\| .${lens}. \|" "the '${lens}' lens row in the roster table"
done
for agent in 'ecc:typescript-reviewer' 'ecc:react-reviewer' 'ecc:vue-reviewer' \
             'ecc:python-reviewer' 'ecc:django-reviewer' 'ecc:fastapi-reviewer' \
             'ecc:go-reviewer' 'ecc:rust-reviewer' 'ecc:java-reviewer' \
             'ecc:kotlin-reviewer' 'ecc:swift-reviewer' 'ecc:cpp-reviewer' \
             'ecc:csharp-reviewer' 'ecc:php-reviewer' 'ecc:fsharp-reviewer' \
             'ecc:flutter-reviewer' 'ecc:database-reviewer' 'ecc:security-reviewer' \
             'ecc:silent-failure-hunter' 'ecc:type-design-analyzer' \
             'ecc:pr-test-analyzer' 'ecc:comment-analyzer' 'ecc:a11y-architect' \
             'ecc:performance-optimizer' 'ecc:mle-reviewer' 'ecc:healthcare-reviewer' \
             'ecc:code-simplifier'; do
  need "${P}" "${agent}" "the '${agent}' default specialist in the roster table"
done
need "${P}" 'Availability is probed'         "the availability probe (never assumed)"
need "${P}" 'a lens is a brief, not a vendor|falls? back to .pr-file-reviewer|fall back to .pr-file-reviewer' \
                                             "the fallback to AIDD's own reviewer when absent"
need "${P}" 'degrade|degraded|degrades'      "graceful degradation of a missing specialist"
need "${P}" 'mode: lens'                     "the degraded lens mode on pr-file-reviewer"
need "${P}" 'never fails a review|never fail' "the no-hard-fail rule on a missing agent"
need "${P}" 'evidence\.md'                   "the evidence/degradation-discipline citation"
need "${P}" 'per-file agent stays the backbone|backbone' "specialists never replacing per-file review"
need "${P}" 'not privileged'                 "a specialist finding entering the same verification"
need "${P}" 'advisory'                       "the advisory-only duplication sweep"
need "${P}" 'pr_review\.roster|roster:'      "the per-repo roster override"
need "${P}" 'disabled by config'             "a lens the repo disabled, recorded not passed"
need "${P}" '### 15\.6'                      "the rigor scaling of the specialist count"
need "${RF}" 'mode: lens|mode=lens'          "the file reviewer's degraded-lens mode"
need "${RF}" 'pr-review/specialists/'        "the specialist artifact path"
need "${TR}" '^## Specialist roster'         "the report's resolved-roster table"
need "${TR}" 'Agent dispatched'              "the dispatched-agent column"
need "${TR}" 'degraded'                      "the degradation status value"
need core/templates/constitution.md 'roster:' "the roster key in the constitution block"
need docs/pr-review.md 'roster'              "the roster in the docs page"
need docs/pr-review.md 'isa-appsec|isa-typescript-review' "the Phoenix custom roster mapping"
need "${D}" 'pr1-spec'                       "the specialist dispatch row"
need "${D}" 'pr-review/specialists/'         "the specialist artifact in the disjointness proof"

# ── 18. The PR-review skill is a skill, not a command
exists skills/aidd-pr-review/SKILL.md
need skills/aidd-pr-review/SKILL.md '^name: aidd-pr-review$' "the skill name"
need skills/aidd-pr-review/SKILL.md '^description: '         "the skill description"
need skills/aidd-pr-review/SKILL.md 'This is a skill, not a command' \
                                             "the skills-are-not-commands statement"
need skills/aidd-pr-review/SKILL.md '/aidd:review-pr'        "the real command it points at"
need skills/aidd-pr-review/SKILL.md 'command-contract\.md'   "the command-contract citation"
need core/protocol/command-contract.md 'aidd-pr-review'      "the contract naming the new skill"
need hooks/scripts/guard-command.sh 'aidd-pr-review'         "the guard allowing the new skill"

# ── 19. The twelve review dimensions, each with a mechanical trigger
need "${P}" '^## 16\. Review dimensions'    "the review-dimensions section"
for dim in 'Diff-coverage' 'Contract / compat' 'Failure-mode analysis' \
           'Rollback & migration safety' 'Feature-flag / kill-switch' 'Observability' \
           'Dependency & supply-chain delta' 'Secrets & sensitive data' \
           'Performance on hot paths' 'Concurrency & idempotency' \
           'Dead / unreachable code and constant drift' 'Unknown-unknowns'; do
  need "${P}" "\*\*${dim}" "the '${dim}' dimension"
done
need "${P}" 'Trigger \(mechanical\)'        "the mechanical trigger column"
need "${P}" 'Evidence that proves the verdict' "the per-dimension evidence standard"
need "${P}" 'FINDINGS \(n\)'                "the per-dimension verdict values"
need "${P}" 'A fired trigger with no row is incomplete by format|fired trigger with no row' \
                                            "the incomplete-by-format rule for a fired dimension"
need "${P}" 'N/A \(trigger not matched\)'   "the honest N/A for a dimension that did not fire"
need "${P}" 'semver'                        "the semver implication on contract changes"
need "${P}" '3am'                           "the production-at-3am failure-mode question"
need "${P}" 'idempot'                       "idempotency of new writes and backfills"
need "${P}" 'N\+1'                          "the N+1 hot-path check"
need "${P}" 'D-008-mocked-proof-patched-add\.md' "the mocked-proof cross-reference in diff-coverage"
need "${P}" '### 16\.1'                     "the per-rigor-mode dimension baseline"
need "${P}" 'fired trigger always adds'     "a fired trigger adding its dimension in every mode"
need "${P}" '### 16\.2'                     "the unknown-unknowns pass"
need "${P}" 'what is NOT in the diff'       "the what-is-not-in-the-diff framing"
need "${P}" 'what should have changed and did not|what SHOULD have changed and did not' \
                                            "the unknown-unknowns question"
need "${P}" 'sibling call site'             "the un-updated sibling call site"
need "${P}" 'second implementation of the same rule left stale' "the stale duplicate implementation"
need "${P}" 'with the search that proves it' "the search that proves an absence claim"
need "${RX}" 'unknown-unknowns'             "the cross-cutting agent's unknown-unknowns duty"
need "${RX}" 'MANDATORY'                    "that duty being mandatory in every mode"
need "${RX}" 'pr-review/unknown-unknowns\.md' "the unknown-unknowns artifact"
need "${RX}" 'semver'                       "the cross-cutting contract/compat duty"
need "${RF}" 'dimensions your unit owns'    "the per-file agent's dimension duties"
need "${D}" 'pr3-unknowns'                  "the unknown-unknowns dispatch row"
need "${D}" 'never skipped in any mode'     "the unknown-unknowns row never being skipped"
need "${TR}" '^## Review dimensions'        "the report's dimension verdict table"
need "${TR}" '^## Unknown-unknowns'         "the report's unknown-unknowns section"
need docs/pr-review.md 'Unknown-unknowns'   "the dimensions in the docs page"

# ── 20. Review quality discipline: the reviewer held to its own standard
need "${P}" '^## 17\. Review quality discipline' "the quality-discipline section"
need "${P}" 'per-lens|per lens'             "the per-lens funnel breakdown"
need "${P}" 'confirm rate'                  "the per-lens confirm rate"
need "${P}" 'Concrete failure scenario \(inputs/state → wrong outcome\)' \
                                            "the concrete-failure-scenario wording from qa-findings"
need "${P}" 'qa-findings\.md'               "the alignment with the pipeline findings template"
need "${P}" 'invalid by format'             "an unscenarioed finding being invalid by format"
need "${P}" 'duplicate-of-linter'           "the no-duplicate-of-linter rule"
need "${P}" 'eslintrc|golangci'             "the linter configs the rule is checked against"
need "${P}" 'Confidence'                    "the confidence field on surviving findings"
need "${P}" 'Blast radius'                  "the blast-radius field on surviving findings"
need "${P}" 'proven'                        "the proven confidence value"
need "${P}" 'traced'                        "the traced confidence value"
need "${P}" '### 17\.5'                     "the refuted-findings appendix rule"
need "${P}" 'refutation reason'             "the refutation reason published with each"
need "${P}" 'never counted as confirmed|never .* posted as comments' \
                                            "refuted findings never posted and never counted"
need "${TR}" '^## Appendix — refuted findings' "the report's refuted appendix"
need "${TR}" 'Refutation reason'            "the refutation-reason column"
need "${TR}" 'Per-lens funnel'              "the per-lens funnel table"
need "${TR}" 'Confidence'                   "the confidence column on confirmed findings"
need "${TR}" 'Blast radius'                 "the blast-radius column on confirmed findings"
need "${TR}" 'duplicate-of-linter'          "the dropped-as-duplicate-of-linter table"
need "${TF}" 'Dimension'                    "the dimension column on findings"
need "${RF}" 'duplicate-of-linter'          "the file reviewer's linter-duplication drop"
need docs/pr-review.md 'duplicate-of-linter' "the quality discipline in the docs page"
need docs/pr-review.md 'Refuted findings ship in an appendix|refuted' "the refuted appendix in the docs"

# ── 21. Docs surface: capability-matrix row and the ADR
need docs/capability-matrix.md 'External PR review' "the capability-matrix row"
need docs/capability-matrix.md 'core/protocol/pr-review\.md' "the matrix row's canonical link"
need docs/design/decisions/019-pr-review.md '^# ADR 019' "the ADR heading"
need docs/design/decisions/019-pr-review.md '\*\*Decision\.\*\*'    "the ADR decision"
need docs/design/decisions/019-pr-review.md '\*\*Why\.\*\*'         "the ADR rationale"
need docs/design/decisions/019-pr-review.md '\*\*Consequence\.\*\*' "the ADR consequence"

exit "${fail}"
