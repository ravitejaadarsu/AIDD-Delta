---
description: Run the AIDD test-engineer team — exhaustive test design + execution — on a fix/story/implementation: $ARGUMENTS
---

**Preflight — the framework must be present.** If `.aidd/framework/` does not exist in this repo, AIDD is not initialized here. STOP and run `/aidd:init` first (it vendors the framework from the installed plugin), or tell the user this repo isn't AIDD-initialized. Do NOT improvise phase logic, invent a playbook, or run ad-hoc tests — running the real vendored playbook is the entire point.

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
