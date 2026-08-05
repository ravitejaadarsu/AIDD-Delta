# Dispatch Protocol

How many agents, who owns which files, parallel or sequential, and in what order — by
**lookup**, never by judgment. The orchestrator does not decide fan-out; it resolves it
from the table below, records the resolved plan, and executes it.

This exists because re-deciding dispatch every step is the framework's largest source of
overhead and drift: the same step gets a different shape on every run, ownership arguments
get re-litigated, and nobody can tell afterwards what was supposed to happen. A table has
none of those failure modes.

## Resolution algorithm

Once per step, in this order:

1. Read the step's `(phase, unit-of-work)` pair from its playbook.
2. Read `rigor.mode` from change state (`rigor-modes.md`). Absent → `standard`.
3. Look up the row. The row gives the unit count for that mode, the ownership rule, the
   dispatch mode, the cap, and the deterministic order.
4. Apply the **ownership rule** (below). Disjointness unproven → sequential.
5. Apply the **cap** — units beyond it queue in the documented order.
6. Record the resolved plan in `supervision/audit.log` (format below).
7. Execute exactly that plan. Do not revisit it within the step.

## Decision table

Unit counts read `fast / standard / critical`. A unit is one dispatch of one role.

| Step | Unit of work | Units (fast / std / crit) | Dispatch | Cap | Deterministic order |
|---|---|---|---|---|---|
| Inception 4 | architecture candidate (lens) | 3 / 3 / 3 | parallel (artifact-disjoint) | 3 | lens asc: `risk-first`, `scalability-first`, `simplicity-first` |
| Inception 5 | judge scorecard | 3 / 3 / 3 | parallel (artifact-disjoint) | 3 | scorecard index asc |
| Inception 6 | architecture synthesis | 1 / 1 / 1 | sequential | 1 | — |
| Inception 7 | independent thinker | 1 / 1 / 1 | sequential (after synthesis) | 1 | — |
| Inception 8 | epic scoper | 1 / 1 / 1 | sequential | 1 | — |
| Inception 9 | story author | one per story | parallel (artifact-disjoint: one story file each) | 6 | story-id asc |
| Inception 10 | impact analyst | 1 / 1 / 1 | sequential | 1 | — |
| Inception 11 | pre-review dimension | 2 / 4 / 4 | parallel (artifact-disjoint) | 4 | dimension asc: `coupling-risk`, `feasibility`, `pattern-fit`, `test-strategy` (fast set: `feasibility`, `pattern-fit`) |
| Construction 1 | evidence capturer (`stage: pre`) | 0 / 1 / 1 | sequential, blocks wave 1 | 1 | — |
| Construction 2a | builder (wave story) | every story in the wave | parallel ONLY if the wave's ownership sets are pairwise disjoint | 4 | story-id asc |
| Construction 2c | Master Agent `mode: monitor` (per wave) | 0 / 1 / 1 | sequential, after the wave's builders return | 1 | wave asc |
| Construction 2d | Auditor interrogation subject (Builder Report) | 0 / one per report | parallel (artifact-disjoint per subject-id) | 4 | subject-id asc; rounds WITHIN a subject strictly sequential |
| Construction 2e | integration check / build fixer | 1 / 1 / 1 | sequential, alone | 1 | — (crosses ownership lines by exemption — never parallel with a builder) |
| QA 1 | post-review dimension (incl. `mode: delta`) | 2 / 6 / 6 | parallel (artifact-disjoint) | 6 | dimension asc: `correctness`, `delta`, `performance`, `security`, `spec-compliance`, `test-coverage` (fast set: `correctness`, `spec-compliance`) |
| QA 1 | security auditor | 0 / 1 / 1 | parallel with the dimension fan-out (own artifact) | 1 | — |
| QA 3 | adversarial verifier (per CRITICAL/HIGH finding) | only if a CRITICAL exists / all / all | parallel; file-grouped if >12 findings | 6 | finding number asc |
| QA 3, 5, 9 | Master Agent `mode: monitor` (per batch) | 0 / 3 / 3 | sequential, one per closed batch | 1 | batch order: review, test, verification |
| QA 4, 5, 10 | debate exchange | 0 / ≤2 (design only) / ≤6 | strictly sequential — an exchange is one challenge plus its response | 1 | surface pipeline order (design → execution → results); within a batched challenge, category asc |
| QA 5 | test engineer (per category) | 2 / 5 / 8 | parallel (artifact-disjoint) | 6 | category asc: `api-contract`, `boundary-edge`, `functional-happy-path`, `impossible-abuse`, `negative-error-handling`, `performance-smoke`, `regression-compat`, `state-concurrency-idempotency` |
| QA 6 | fix-loop builder (per defect group) | one per owning story | parallel ONLY if the owning stories' ownership sets are pairwise disjoint | 4 | story-id asc |
| QA 7 | E2E verifier | 0 / 1 / 1 | sequential, alone — clean state means nothing else runs | 1 | — |
| QA 8 | evidence capturer (`stage: post`) | 0 / 1 / 1 | sequential | 1 | — |
| QA 9 | AC assessor | 1 / 1 / 1 | sequential | 1 | — |
| QA 11 | tally | 0 / 1 / 1 | sequential | 1 | — |
| QA 12 | Auditor final audit subject | 0 / one per subject | parallel (artifact-disjoint per subject-id) | 4 | subject-id asc |
| QA 13 | negotiation (per disputed AC) | 0 / ≤1 / ≤2 exchanges | strictly sequential, one AC at a time (the counter resets per AC) | 1 | ac-id asc |
| QA 16 | critic | 1 / 1 / 1 | sequential | 1 | — (never skipped) |
| Delivery 1 | doc writer + delivery-agent prep | 2 / 2 / 2 | parallel ONLY if the doc set and the commit set are disjoint | 2 | documented fallback: Doc Writer, then Delivery Agent |
| Delivery 2–4 | delivery agent | 1 / 1 / 1 | sequential | 1 | — |
| Delivery 6 | Supervisor final session report | 1 / 1 / 1 | sequential | 1 | — |
| Retro 1 | retro learner | 1 / 1 / 1 | sequential | 1 | — |
| Every phase boundary | Supervisor phase audit | 1 / 1 / 1 | sequential | 1 | — (never skipped in any mode) |

## Ownership rule (mechanical)

Parallel dispatch is permitted **only** when the units' file-ownership sets are provably
pairwise disjoint per `file-scope.md`. Three ways a plan proves it, and one that does not:

1. **Artifact-disjoint by construction** — each unit writes exactly one artifact named by
   its own unit key (`pre-review/<dimension>.md`, `qa/tests/<category>.md`,
   `arch-candidates/<lens>.md`, `audit/interrogation/<subject-id>-*.md`). Distinct keys ⇒
   distinct paths ⇒ disjoint. No further reasoning needed.
2. **Declared-ownership-disjoint** — builders. The orchestrator pairwise-intersects the
   wave's `file_scope.owns` exact paths and `file_scope.creates` prefixes
   (`file-scope.md` rule 1). Empty intersections ⇒ parallel.
3. **Append-shared ⇒ never parallel** — two units appending to the SAME file
   (`audit/negotiation-log.md`, one `audit/debate/<category>.md`, a story file's report
   sections) are sequential, always, whatever the table's cap says.
4. **Unproven ⇒ sequential.** If disjointness cannot be proven from the epic's ownership
   sets or from rule 1, the answer is sequential in the row's documented order. There is no
   case-by-case reasoning, no "probably fine", no reading the code to guess.

Sequential order is the row's **deterministic order** — story-id, dimension name, category
name, subject-id, or ac-id, ascending. Ascending means byte-wise ascending on the exact
identifier string, so two runs of the same step produce the same order.

## Runtime without parallelism

The fallback is not a different plan — it is the same units, the same count, the same
order, run one at a time. Results are order-independent because units communicate only
through artifacts (`../playbooks/00-pipeline.md`). The recorded plan states
`mode=sequential reason=runtime-no-parallel`, so the degradation is explicit and the
Supervisor can see the plan was not silently reshaped.

## Batching rule

Units beyond the cap **queue** in the documented order and dispatch as slots free. Never
spawn beyond the cap to go faster: the cap is what keeps the context and the audit trail
of a step bounded. Never drop queued units to fit the cap either — a unit the table
requires runs, or the step is incomplete.

## Never re-decide

The table is consulted **once per step**. The orchestrator records the resolved plan and
must not revisit it within the step — not after a slow unit, not after a failure, not
because a returning unit suggests a different split. A unit that fails follows its own
remediation ladder in its playbook (re-dispatch, blocked path, fix loop); remediation
re-dispatches the SAME unit, it does not re-shape the plan.

**Re-deciding a dispatch plan mid-step is a supervision VIOLATION.** The evidence of the
breach is the audit log itself: two `dispatch-plan` lines for one step token, or executed
dispatches that do not match the recorded plan. A step whose scope genuinely changed
(backflow delta stories, an escalated rigor mode) does not re-decide the old step — it
starts a NEW step with a new token and its own single plan.

Recorded as one line in `supervision/audit.log` (`supervision.md` format, role
`orchestrator`, status `dispatched`):

```text
2026-08-06T10:14:02Z | construction | orchestrator | wave-2 | dispatched | dispatch-plan units=3 agents=3 mode=parallel cap=4 order=ST-004,ST-005,ST-006
```

## Worked examples

### Inception — pre-review, `standard`

Row `Inception 11`: units 4, parallel (artifact-disjoint), cap 4, dimension asc.

```text
units   = coupling-risk, feasibility, pattern-fit, test-strategy
agents  = 4 (Reviewer mode=pre, one dimension each)
order   = as listed (ascending); parallel — each writes only pre-review/<dimension>.md
queue   = none (4 ≤ cap 4)
```

In `fast` the same row yields 2 units (`feasibility`, `pattern-fit`), 2 agents, same rule.

### Construction — 7 stories, 3 waves, `standard`

`epic.md`: wave 1 = ST-001, ST-002, ST-003, ST-004, ST-005 (all ownership sets pairwise
disjoint); wave 2 = ST-006, ST-007 (disjoint); wave 3 = ST-008, the seam story, solo.

```text
wave 1  builders: units 5, disjoint ⇒ parallel, cap 4
        ⇒ agents 4 (ST-001..ST-004), ST-005 queued, dispatched as the first slot frees
        then 1× Master Agent monitor (wave-1)
        then Auditor interrogation: 5 subjects, artifact-disjoint ⇒ parallel, cap 4
             ⇒ 4 subjects, 5th queued; 1 round each (standard)
        then integration check (sequential, alone)
wave 2  builders: units 2, disjoint ⇒ parallel, 2 agents
        then monitor ×1, interrogation 2 subjects (parallel), integration check
wave 3  builders: units 1 (seam) ⇒ sequential by count
        then monitor ×1, interrogation 1 subject, integration check
```

Three plan lines, one per wave; 3 monitoring notes; 8 interrogation verdicts. Nothing about
this is re-decided when ST-005 returns late — it takes the freed slot, and the plan stands.

### QA — `standard`, 9 findings (2 CRITICAL, 3 HIGH, 4 MEDIUM)

```text
step 1  6 dimension units (5 + delta) ⇒ parallel, cap 6 ⇒ 6 agents
        + 1 security auditor in parallel (own artifact)
step 3  adversarial verifier: units = CRITICAL/HIGH only = 5 ⇒ parallel, cap 6 ⇒ 5 agents
        order = finding number asc; MEDIUMs get no verifier (advisory unless escalated)
        + 1 Master Agent monitor (review batch, sequential, after the batch closes)
step 5  test engineer: 5 categories (standard) ⇒ parallel, cap 6 ⇒ 5 agents
        debate: design surface only, ≤2 exchanges, strictly sequential
step 7  E2E verifier alone; step 8 evidence post; step 9 AC assessor; step 11 tally
step 12 auditor final audit subjects ⇒ parallel, cap 4, 1 round each
step 13 negotiation: one disputed AC at a time, ac-id asc, ≤1 exchange each
```

In `critical` the same step 5 row yields 8 categories: 6 dispatch, 2 queue.

### Delivery — `standard`

Row `Delivery 1`: 2 units. The Doc Writer edits `docs/**`, README, CHANGELOG; the Delivery
Agent commits the whole tree. The commit set is not disjoint from the doc set, so rule 4
applies:

```text
units  = doc-writer, delivery-agent-prep
proof  = commit set ⊇ doc set ⇒ NOT disjoint
plan   = sequential, documented order: doc-writer, then delivery-agent-prep
```

Then steps 2–4 sequential (1 agent), the Supervisor final report, and the phase boundary
audit — the two dispatches no mode and no table row ever removes.
