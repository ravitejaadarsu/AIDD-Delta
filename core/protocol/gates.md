# Gate Protocol

Three human-relevant gates plus one QA sub-gate. Construction/Delivery exits are
evidence-only (no approval semantics).

| Gate | Key | After | Artifacts bound |
|---|---|---|---|
| G1 | `g1_prd` | PRD drafted | `prd.md` |
| G2 | `g2_plan` | Pre-implementation review resolved | `architecture.md`, `epic.md`, `stories/*`, `pre-review/*` |
| G3 | `g3_premerge` | QA verdict computed | `qa/*`, `ac-matrix.md`, `evidence/post/*` |
| test-report | `g_test_report` | Exhaustive test report consolidated | `qa/test-report.md` |

## Uniform mechanism (both modes)

At a gate the orchestrator always:

1. Computes a **gate digest**: ≤20 lines — key decisions, assumptions, risks, and (G3) the
   verdict table + diff stats; plus the artifact list with sha256 hashes.
2. Obtains a **disposition**:
   - `let-me-look`: set `phase_status: awaiting_gate`, present the digest, STOP. Accepted
     responses: **approve** · **revise: <notes>** (notes routed to the owning agent, artifact
     regenerated, gate re-presented) · **abort** (halt, state preserved).
   - `take-care`: disposition is `approve` recorded as `approved_by: auto` — UNLESS an
     escalation flag is set (open BLOCKING question, disjointness CONCERNS, unresolved
     pre-review CRITICAL, open CONFIRMED finding, open test FAIL, AC matrix FAIL, unresolved
     supervision VIOLATION), in which case this gate behaves exactly like `let-me-look`.
3. Appends the gate entry to `gates` in change state and advances.

## The `g_test_report` sub-gate

After the exhaustive test report is consolidated (QA step 9), the orchestrator seeks
approval before annotating stories with the report. Same mechanism as above; on approval
it records `g_test_report` AND writes a `## Test Report` section into every affected story
(report path + pass/fail tally). In `take-care` this auto-approves unless an executed FAIL
is still open. This is how "mention it in the story on approval" is enforced.

## Staleness (precision rule)

Approval binds to content: the entry records each artifact's sha256. If a gated artifact
changes afterwards (e.g. QA backflow amends architecture.md), the gate flips to `stale` and
must re-pass before the pipeline proceeds past it again. Auto and human approvals share an
identical entry structure, so the audit trail reads the same in both modes.

## Quality gates (mode-independent)

`tests_green, exhaustive_tests_passed, qa_findings_resolved, e2e_verified,
mutation_floor_met, security_clean, perf_within_budget, acs_verified, evidence_captured,
supervision_compliant` — all must be `passed` (or explicitly `na` with a recorded reason)
before Delivery pushes anything. Autonomy modes modulate human approval, never quality.
