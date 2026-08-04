# Gate Protocol

Three human-relevant gates plus one QA sub-gate. Construction/Delivery exits are
evidence-only (no approval semantics).

| Gate | Key | After | Artifacts bound |
|---|---|---|---|
| G1 | `g1_prd` | PRD drafted | `prd.md` |
| G2 | `g2_plan` | Pre-implementation review resolved | `architecture.md`, `counter-arguments.md`, `impact-report.md`, `epic.md`, `stories/*`, `pre-review/*` |
| G3 | `g3_premerge` | QA verdict + critic verdict computed | `qa/*`, `qa/critic-verdict.md`, `ac-matrix.md`, `evidence/post/*` |
| test-report | `g_test_report` | Exhaustive test report consolidated | `qa/test-report.md` |

## Uniform mechanism (both modes)

At a gate the orchestrator always:

1. Computes a **gate digest**: ≤20 lines — key decisions, assumptions, risks, the
   counter-arguments and impact rating (G2), and the verdict table + critic verdict + diff
   stats (G3); plus the artifact list with sha256 hashes.
2. Obtains a **disposition**:
   - `let-me-look`: set `phase_status: awaiting_gate`, present the digest, STOP. Accepted
     responses: **approve** · **revise: <notes>** · **abort**.
   - `take-care`: disposition is `approve` recorded as `approved_by: auto` — UNLESS an
     escalation flag is set (open BLOCKING question, disjointness CONCERNS, unresolved
     pre-review CRITICAL, open CONFIRMED finding, open test FAIL, AC matrix FAIL, critic
     REJECT, unresolved supervision VIOLATION, UNRESOLVABLE adjudication ruling (disputed
     AC without a PROVEN/DEFECT resolution)), in which case this gate behaves exactly like
     `let-me-look`.
3. Appends the gate entry to `gates` in change state and advances.

## The `g_test_report` sub-gate

After the exhaustive test report is consolidated (QA step 14), the orchestrator seeks
approval before annotating stories with the report. On approval it records `g_test_report`
AND writes a `## Test Report` section into every affected story. In `take-care` this
auto-approves unless an executed FAIL is still open.

## The critic verdict

The Critic (QA step 16) returns APPROVE / APPROVE WITH CONDITIONS / REJECT, setting the
`critic_approved` quality gate: APPROVE→passed, CONDITIONS→passed (conditions recorded in
the ledger + PR body), REJECT→failed (blocks G3; re-enter the fix loop or escalate).

## Staleness (precision rule)

Approval binds to content: the entry records each artifact's sha256. If a gated artifact
changes afterwards, the gate flips to `stale` and must re-pass. Auto and human approvals
share an identical entry structure.

## Quality gates (mode-independent)

`tests_green, exhaustive_tests_passed, qa_findings_resolved, e2e_verified,
mutation_floor_met, security_clean, perf_within_budget, acs_verified, evidence_captured,
supervision_compliant, critic_approved, auditor_approved, debate_complete,
tally_reconciled` — all must be `passed` (or explicitly `na` with a recorded reason)
before Delivery pushes anything. Autonomy modes modulate human approval, never quality.
