# Delta improvement plan

Aim: useful, reproducible verification across different engineering tasks. Broad superiority
is an evaluation target, not a product guarantee. Priorities below are ordered; they do not
promise dates or imply features are already implemented.

## 1. Deterministic enforcement — implemented in this change

Portable delivery preflight, complete artifact approval bindings, invalid-exemption rejection,
and behavioral regression tests. See [delivery-readiness.md](delivery-readiness.md).
Acceptance: missing, stale and contradictory state blocks delivery with an actionable error;
valid fast, standard and critical fixtures pass without a model call.

## 2. Source-bound evidence — next

Capture execution receipts containing argv, working directory, source-tree fingerprint,
exit code, timestamps, tool versions and output digest. Bind AC evidence to receipts; reject
proof after a relevant source change. Test timeout, interruption, nonzero exits, dirty and
untracked files, and missing tools. Never execute shell text extracted from a report.
Acceptance: changing source invalidates its old proof; failed or interrupted execution cannot
be presented as a passing receipt. Receipts remain distinct from semantic proof of an AC.

## 3. Use-case coverage — next

| Use case | Required demonstration | Primary outcome |
|---|---|---|
| Documentation / copy | Tiny reversible edit through fast mode | Time and cost without irrelevant work |
| Bug fix | Reproducer fails before and passes after | Regression fixed without unrelated breakage |
| API / SDK | Compatibility and negative contract cases | Breaking changes detected |
| UI | Keyboard, loading, error and responsive states | Executed interaction evidence |
| Auth / tenant isolation | Cross-role and cross-tenant negative cases | Unauthorized access rejected |
| Migration / data pipeline | Representative fixtures, rollback and invariants | Data preserved and recovery demonstrated |
| Infrastructure | Validate, plan and rollback rehearsal in isolation | No unintended resource changes |
| Concurrency / performance | Repeatable load, race and idempotency fixtures | Correctness and latency budgets |

Use existing rigor modes; add proof adapters only when a fixture demonstrates a gap. A
missing tool must produce an explicit blocker or an allowed, documented degradation.
Acceptance: at least one reproducible task and one plausible seeded defect per row, with
objective scoring independent of the generating agent. Optional paid or cloud tools cannot
be prerequisites for the offline framework self-tests.

## 4. Comparative evaluation

Use the existing benchmark harness with pinned repository revisions, model configuration,
tool access and budgets. Compare plain-agent, Superpowers, AI-DLC and Delta arms on matched
tasks with repeated runs. Add an ablation arm disabling extra Delta review layers to measure
their incremental value. Keep held-out tasks separate from the defects used during design.
Acceptance: publish raw artifacts, failures and denominators alongside task success, defect
recall, false alarms, elapsed time, cost and human interventions. Label missing measurements;
never substitute zero. Do not claim a winner from framework self-tests.

## 5. Independent adoption and release

Ask independent developers to reproduce the quickstart and use-case fixtures. Record setup
failures, confusing output and total time to first verified result. Prioritize those fixes
before adding roles. Add CI enforcement after defining trust and approval boundaries.
Acceptance: three independently reproduced case studies, documented upgrade behavior,
negative results, and a release checklist tied to actual tests and evaluated tasks.
