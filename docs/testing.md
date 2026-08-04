# Exhaustive Testing

Canonical: `core/roles/test-engineer.md`; QA steps 4, 5, 10 + 14 in
`core/playbooks/40-qa.md`; debate protocol `core/protocol/test-debate.md`.

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

## The debate (tests are contested, not trusted)

Nothing here is taken on trust. `core/protocol/test-debate.md` (ADR 009) contests the tests
themselves on three surfaces, in pipeline order:

1. **Design** (step 4, before ANY case runs) — testers publish their matrices; the Master
   Agent and the Auditor challenge coverage — missing edge cases, weak AC mapping, flows that
   do not exercise the AC they claim — in one batched challenge artifact. Testers **amend** or
   **defend**. A weak design costs one exchange here instead of a whole execution round later.
2. **Execution** (inside step 5) — as each category's results land the Auditor contests
   specific TCs (wrong assertion, mocked path where real proof was demanded). The owning tester
   re-executes **only** the contested TCs — max **2 exchanges total on the surface, not per
   category**.
3. **Results** (step 10) — a disputed PASS in `qa/test-report.md` is re-proven **live**:
   **Playwright MCP** drives UI-facing flows in a real browser and the screenshots become the
   evidence; non-UI flows re-run as CLI/API transcripts. Re-citing the original run proves
   nothing. Runtimes without Playwright MCP fall back to the vendored
   `core/templates/playwright-capture.mjs` script, and the record says which path ran —
   degradation is explicit, never silent.

**Budgets are hard.** One exchange = one challenge artifact + its response, as a pair (a
batched round covering every category is **1** exchange). Per-surface caps are 2 / 2 / 2, all
drawing from one shared pool of **6 exchanges per change** that dominates them — 2+2+2 fully
subscribes it, and an unused design exchange never rolls over into another surface. Spend is
tracked in change state `audit.debate.exchanges_used` and mirrored in the budget-arithmetic
line of each record (`audit/debate/<category>.md`, template
`core/templates/debate-record.md`), which the Supervisor checks.

**Every item terminates.** Amended, defended, or — at exhaustion — **DISPUTED** if it cites
AC ids, which sends those ACs into the normal negotiation ladder
(`core/protocol/negotiation.md`: accept → `DEFECT`, else Supervisor adjudication), or
**advisory** if it maps to no AC (a `performance-smoke` observation), which never blocks.
Test designs that a challenge invalidated feed `learnings.md`, like refuted review findings.
`debate_complete` — set by the orchestrator once all three surfaces close within budget, and
only by it — is a mode-independent gate.

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
