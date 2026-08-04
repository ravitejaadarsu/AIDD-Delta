# Exhaustive Testing

Canonical: `core/roles/test-engineer.md`; QA step 5 + 14 in `core/playbooks/40-qa.md`.

AIDD Delta runs a **team of senior test engineers** over every fix / user story /
implementation — including pure API changes. It is deliberately dull and exhaustive: it
tries the possible AND the impossible, and it actually executes the cases rather than just
listing them.

## The team (one tester per category)

- `functional-happy-path` — every AC exercised
- `negative-error-handling` — invalid inputs, error paths, partial failures, rollback
- `boundary-edge` — min/max, off-by-one, empty/one/many, unicode, null vs absent
- `impossible-abuse` — malformed/injection/oversized/contradictory inputs; must be
  rejected gracefully (never crash, corrupt, or silently succeed)
- `api-contract` — schema, status codes, error envelope, auth, pagination, idempotency,
  versioning, and backward-compatibility / breaking-change detection
- `state-concurrency-idempotency` — retries, double-submit, races, restart consistency
- `regression-compat` — existing behavior + mined invariants still hold
- `performance-smoke` — bench commands within budget, no leak/blowup

Each category is a subagent dispatch (parallel on Claude Code, sequential elsewhere) that
designs `TC-<CAT>-NNN` cases, automates them where possible under an owned exploratory
test dir, executes them, and records PASS/FAIL/BLOCKED/NA with evidence.

## Results & the story link

The orchestrator consolidates every category file into one end-results file,
`qa/test-report.md` (summary matrix, AC coverage, open defects, evidence). Every executed
FAIL feeds the QA fix loop (bounded, TDD fixes). **On your approval** (auto in `take-care`
unless a FAIL is still open), the report is linked into each affected story under a
`## Test Report` section with the pass/fail tally, and the `g_test_report` gate is recorded.

`exhaustive_tests_passed` is a mode-independent quality gate — it blocks delivery in both
autonomy modes.

## Standalone

Run the team without the full pipeline: `/aidd:test <story|fix|api>` (Claude Code) or
"AIDD: test <target>" / `.aidd/framework/prompts/test.md` (any CLI).
