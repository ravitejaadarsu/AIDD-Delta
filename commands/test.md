---
description: Run the AIDD test-engineer team — exhaustive test design + execution — on a fix/story/implementation: $ARGUMENTS
---

Run the AIDD exhaustive-testing team on the target: $ARGUMENTS (a story id, a fix/diff, an
API surface, or — if omitted — the active change's implementation).

1. Read `.aidd/framework/roles/test-engineer.md`.
2. Dispatch the `aidd-test-engineer` subagent once per test category
   (functional-happy-path, negative-error-handling, boundary-edge, impossible-abuse,
   api-contract, state-concurrency-idempotency, regression-compat, performance-smoke),
   in parallel. Each designs an exhaustive case matrix AND executes it, writing
   `qa/tests/<category>.md`.
3. Consolidate every category file into a single end-results file `qa/test-report.md`
   (use `.aidd/framework/templates/test-report.md`). Route every FAIL into the QA fix loop
   per `.aidd/framework/playbooks/40-qa.md`.
4. Present the report summary and **ask for approval**. On approval (auto in `take-care`
   unless failures remain — see `.aidd/framework/protocol/gates.md`), write a
   `## Test Report` section into each affected story file linking `qa/test-report.md` with
   the pass/fail tally, and record the `g_test_report` gate entry.
