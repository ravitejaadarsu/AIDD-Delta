# Three-Layer Verification Architecture — Design

- **Date:** 2026-08-04
- **Status:** Design approved by the user in three staged checkpoints (① architecture &
  roles, ② protocols, ③ snapshots/delta review/plumbing) plus all six decisions in the
  table below. The written spec itself is pending user review.
- **Version target:** v0.3.0
- **Approach:** B — three literal layer agents (user-selected over "layer on top" and "restructure QA")

## Goal

Make AIDD-Delta's verification competitive with the industry's best AI agent systems by
adding a dedicated three-layer precision architecture — quality over speed — plus three
advancements: repo-level snapshot context, pre/post delta review, and a continuous
test-debate protocol executed live through Playwright MCP.

An intent kicks out worker sub-agents (Layer 1); a dedicated Master Agent monitors all
sub-agent work (Layer 2); an Auditor directly interrogates sub-agents and validates their
work against Jira story acceptance criteria, then negotiates with the Master Agent
(Layer 2); all of their outputs form the super-context consumed by the Supervisor
(Layer 3), whose verdict gates phase advance.

## Decisions locked with the user

| # | Question | Decision |
|---|----------|----------|
| 1 | How does the Auditor "directly talk" to sub-agents? | Artifact-mediated interrogation rounds (bounded challenge/response files) — keeps the "artifacts are the only inter-agent channel" invariant and Codex portability |
| 2 | When does the Auditor run? | Both: per construction wave AND a final consolidated audit in QA |
| 3 | Snapshot content & cadence | Full context pack (structure + API surface + measured quality baseline + delta), rebuilt at every phase boundary and after every construction wave |
| 4 | Pre/post review shape | New `mode=delta` on the existing parameterized Reviewer |
| 5 | Where does the test debate happen? | Full continuous debate: design time + per-category execution + results, with strict shared budgets |
| 6 | Overall architecture | Approach B: dedicated Master Agent + Auditor agents; Master Supervisor renamed to Supervisor and promoted to Layer 3; Critic untouched |

## Architecture

### Layer 1 — Workers (existing, unchanged roster)

Builders, Test Engineers, Reviewers, Security Auditor, Evidence Capturer, AC Assessor,
E2E Verifier, etc. Fan-out per wave/category/dimension exactly as today. The orchestrator
(main session) remains the only dispatcher and the single writer of state — it is the
runtime's main loop and cannot be replaced by a subagent.

### Layer 2 — Monitoring & Audit (new)

**Master Agent** — `core/roles/master-agent.md` + `agents/aidd-master-agent.md`.
`stage_class: adjudicative`, tools: read-only code; writes exactly three artifact kinds —
monitoring reports (`audit/monitoring/*`), its own negotiation-log entries
(`audit/negotiation-log.md`), and its debate-record contributions (`audit/debate/*`).

- Dispatched after every construction wave and after every QA step batch.
- Reviews each returning sub-agent report for *quality of work* (substantive judgment:
  is the evidence convincing, is the work honest, are corners cut) — NOT process
  compliance (Layer 3) and NOT dispatch mechanics (orchestrator).
- Writes `audit/monitoring/<phase>-<step>.md` notes.
- Is the Auditor's negotiation counterpart; participates in test-design debates.

**Auditor** — `core/roles/auditor.md` + `agents/aidd-auditor.md`.
`stage_class: adjudicative`, tools: read-only code + Bash probes (probes under
`.aidd/probes/` only, never committed — same rule as the Adversarial Verifier); writes
`audit/interrogation/*` (challenges + verdicts), its negotiation-log entries, its
debate-record contributions, and appends `## Auditor Report` sections to story files.

- **Construction:** after each wave's TDD-evidence check, interrogates every Builder
  Report against the story's `ac_ids` via the interrogation protocol.
- **QA:** final consolidated audit — interrogates tester and reviewer outputs, and
  contests the AC matrix row-by-row (it consumes the AC Assessor's matrix; it never
  duplicates it).
- Emits per-story verdicts: each AC is `PROVEN` or `DISPUTED`.
- DISPUTED ACs it cannot settle with the sub-agent go to negotiation with the Master
  Agent.
- Jira access: read-only, reusing the existing pull ladder in
  `core/protocol/jira-sync.md` (MCP → REST → human paste). No new Jira surface.

### Tally — the reconciliation agent (Layer 2, mechanical)

**Tally** — `core/roles/tally.md` + `agents/aidd-tally.md`. `stage_class: mechanical`,
tools: read-only code + Jira read ladder (per `core/protocol/jira-sync.md`); writes
`qa/tally.md` only.

- Dispatched once in QA, after post-evidence capture (so both `evidence/pre/` and
  `evidence/post/` exist), before the Critic.
- **Mission:** tally every tracked work item the change references — Jira stories,
  tasks, bugs, and any custom issue type (e.g. "bolt") — against the implementation.
  For each item: the ACs it carries, the stories that claimed it, the diff files that
  realized it, the tests that prove it, and the **before/after evidence** links from
  the evidence manifest.
- **Output:** `qa/tally.md` (new template `core/templates/tally.md`) — one row per work
  item: `item id | type | ACs | stories | diff files | tests | pre evidence |
  post evidence | verdict RECONCILED / GAP`. Plus an **orphans section**: diff files
  traceable to no work item.
- **GAP routing:** gaps use existing channels — a missing AC proof feeds the AC-matrix
  fix loop; an orphaned diff becomes a finding for adversarial verification. Tally
  itself never blocks directly; the new mode-independent quality gate
  `tally_reconciled` passes only when every row is RECONCILED and no orphans remain
  (or gaps are explicitly waived at G3).
- Tally's matrix joins the super-context consumed by the Critic and Supervisor.

### Layer 3 — Supervision (evolved)

**Supervisor** — `core/roles/master-supervisor.md` is **renamed** to
`core/roles/supervisor.md` (agent wrapper `agents/aidd-supervisor.md`), keeping its
process-audit charter and gaining:

- **Super-context inputs:** every Layer-1 artifact + `audit/monitoring/*` +
  `audit/interrogation/*` + `audit/negotiation-log.md` + `audit/debate/*` + the Critic's
  verdict + `supervision/audit.log` + change state.
- **Negotiation adjudication:** when Auditor ↔ Master Agent negotiation exhausts its
  budget, the Supervisor rules from the evidence. The adjudication output is a separate
  per-AC ruling — `PROVEN | DEFECT | UNRESOLVABLE` — appended to
  `audit/negotiation-log.md` and mirrored into the change-state `audit` block.
  `UNRESOLVABLE` makes the gate forced-human (both autonomy modes).
- Its **phase verdict** vocabulary is unchanged: `COMPLIANT | VIOLATIONS`; VIOLATIONS
  still block phase advance; repeat violation = phase FAIL + human escalation. The
  adjudication ruling above is a distinct, additional output — not a third phase verdict.

**Critic — untouched.** Its consolidated product verdict (`APPROVE / APPROVE WITH
CONDITIONS / REJECT`) remains the last product verdict before the final Supervisor audit
and becomes part of the super-context. (The QA playbook's steps are renumbered by the
insertions this spec makes; the spec therefore uses relative anchors — "before the
Critic", "the final Supervisor audit" — never absolute step numbers.)

### Blocking economy amendment (ADR 006)

Today only CONFIRMED findings, executed test FAILs, and a Critic REJECT block. One new
blocking channel: **an AC that exits the interrogation → negotiation → adjudication
ladder as DISPUTED (or as a `DEFECT` ruling), at whichever rung the ladder terminates,
blocks** — it enters the QA fix loop as a defect, exactly like a CONFIRMED finding. The
ladder can terminate early: the Master Agent concurring with the Auditor skips
negotiation entirely, and a negotiation "accept" skips adjudication. Layer-2 outputs
with no AC mapping (monitoring notes, debate records on non-AC items) are advisory
context, never blockers.

## Protocols

### Interrogation protocol — `core/protocol/interrogation.md`

Artifact layout under `.aidd/changes/<id>/audit/`:

```
audit/
  interrogation/
    <story-id>-round1-challenge.md   Auditor: disputed ACs, evidence gaps, exact proof demanded
    <story-id>-round1-response.md    sub-agent re-dispatched to answer with executed evidence
    <story-id>-round2-challenge.md
    <story-id>-round2-response.md
    <story-id>-verdict.md            AC-by-AC: PROVEN | DISPUTED
```

- A challenge names the AC id, the evidence gap, and the exact proof demanded.
- Responses must use the mandatory evidence-block format (`core/protocol/evidence.md`):
  command + trimmed output + exit code + timestamp.
- Budget: **max 2 rounds** per story/report. After round 2 every AC is PROVEN or
  DISPUTED. DISPUTED → negotiation.
- In QA, the same file pattern applies with tester/reviewer report ids in place of
  story ids.
- The orchestrator dispatches all parties; agents never talk live. Replayable, resumable,
  portable.

### Negotiation protocol — `core/protocol/negotiation.md`

- Trigger: Auditor holds DISPUTED **and** the Master Agent's monitoring notes accept the
  work. **Short-circuit:** if the Master Agent concurs with the Auditor that the work is
  deficient, negotiation is skipped — the DISPUTED AC becomes a fix-loop defect directly.
- Channel: `audit/negotiation-log.md` — Auditor position (+evidence) → Master Agent
  response: **accept** (AC becomes a fix-loop defect; no adjudication needed) or
  **contest** (+counter-evidence).
- Budget: **max 2 exchanges** per disputed AC (1 exchange = one position artifact + its
  response).
- Exhaustion → Supervisor adjudicates from super-context, ruling per AC:
  `PROVEN` (dispute dismissed) | `DEFECT` (fix-loop) | `UNRESOLVABLE` → forced-human gate
  (same pattern as fix-loop exhaustion; applies in take-care mode too).
- Every outcome is one log line + mirrored into change state (`audit` block).

### Continuous test-debate protocol — `core/protocol/test-debate.md`

Three surfaces, hard budgets, records under `audit/debate/<category>.md`:

**Accounting unit:** 1 exchange = one challenge artifact + its response, as a pair. A
batched design-debate round covering all categories in one challenge artifact counts as
**1 exchange**. The shared cap **strictly dominates** every per-surface allowance, and
surfaces draw from the pool in pipeline order: design first, then execution, then results.

1. **Design debate** — Test Engineers publish their TC matrices BEFORE executing;
   Master Agent + Auditor challenge coverage (missing edge cases, weak AC mapping, wrong
   flows) in one batched challenge artifact per round; testers amend or defend. Max
   **2 exchanges** on this surface.
2. **Execution debate** — as each category's results land, the Auditor may contest
   specific TCs (wrong assertion, mocked path where real proof was demanded); the tester
   re-executes only the contested TCs. Contests are batched per dispatch wave; max
   **2 exchanges total** on this surface (not per category).
3. **Results debate** — over consolidated `qa/test-report.md`: disputed PASSes are
   re-proven live — **Playwright MCP** browser runs for UI-facing flows (screenshots
   attached as evidence), CLI/API transcripts otherwise. Runtimes without Playwright MCP
   fall back to the existing `core/templates/playwright-capture.mjs` script (explicit
   degradation, never silent). Max **2 exchanges** on this surface.
- **Shared budget: 6 exchanges per change** across all three surfaces (2+2+2 fully
  subscribes it; an unused design exchange does NOT roll over — per-surface caps hold).
- **AC mapping is mandatory:** every debate item cites the AC id(s) the contested test
  evidences (TCs already thread `ac_ids`). On exhaustion, a still-contested item marks
  its mapped AC(s) DISPUTED and enters the negotiation ladder as a normal disputed AC. A
  contested item with no AC mapping (e.g. performance-smoke) is recorded as advisory —
  it never blocks and never enters negotiation.
- Debate outcomes that invalidate test designs feed `learnings.md`, like REFUTED
  findings do today.

## Snapshot context system

`core/protocol/context-snapshots.md` + `core/scripts/build-snapshot.sh` (zero-dependency
per ADR 002 — bash + python3 stdlib permitted — mirroring `render-dashboard.sh`, which is
itself a bash wrapper around an inline python3 heredoc).

```
.aidd/context/                 (gitignored; never committed, never pushed)
  snapshot.md                  repo tree + module map + public API surface + entry points
  quality-baseline.md          measured sigmas: test count, coverage %, lint status,
                               complexity hotspots, file-size outliers — every number
                               carries its command + exit code (evidence protocol)
  delta.md                     git diff --stat + churn since previous snapshot
  history/<ISO>-<tag>/         prior packs: pre-inception, post-wave-1, … (iteration trail)
```

- **Rebuild cadence:** every phase boundary + after every construction wave. Orchestrator
  duty; hook-assisted on Claude Code (new `hooks/scripts/build-snapshot.sh` entry in
  `hooks/hooks.json`), protocol text on other runtimes.
- **Consumption:** every role's Inputs section gains "read `.aidd/context/snapshot.md`
  (+ `quality-baseline.md` where relevant) FIRST; do not re-crawl the repo." This is the
  context-window relief: one compact pack instead of repeated repo exploration.
- **Resume rule:** snapshots are never trusted across resume — rebuilt before continuing
  ("re-prove, never trust").
- `install.sh` gains logic to append `.aidd/context/` to the target repo's `.gitignore`
  (creating the file/entry if absent — there is no `.gitignore` template today); this
  repo's own `.gitignore` gains the entry too.

## Delta review — Reviewer `mode=delta`

Third mode on the existing parameterized Reviewer (`core/roles/reviewer.md`); dispatched
in QA step 1 alongside the post dimensions.

- **Inputs:** pre-implementation snapshot pack from `.aidd/context/history/`, the
  per-dimension pre-review findings set `pre-review/<dimension>.md` (plan intent — this
  is the artifact the Inception pre-review actually produces), the full Construction
  diff, `quality-baseline.md` (current vs pre).
- **Judges three bindings:**
  1. **intent-fidelity** — the implementation honors what the plan meant, not just what
     tests pass;
  2. **structure-fit** — the diff matches the repo's structural conventions per the
     snapshot structure map;
  3. **sigma-regression** — measured quality did not regress beyond tolerance (coverage
     down, complexity up, lint broken) vs the pre baseline.
- **Output:** `qa/findings-delta.md` in the standard findings format (severity, file:line,
  claim, concrete failure scenario) → existing funnel: collate → adversarial verification
  → fix loop. A finding without a concrete scenario remains invalid by format.

## State, schema, and plumbing changes

- **`core/schemas/change-state.schema.json`:**
  - `quality_gates` gains `auditor_approved`, `debate_complete`, and `tally_reconciled`
    (enum `pending|passed|failed|na`, mode-independent).
  - New `audit` block: interrogation round counters, negotiation exchange counters,
    debate budget spent (mirrors the `fix_loop {iteration, max}` shape).
- **Story files:** Auditor appends `## Auditor Report` sections (append-to-artifact
  convention); **no frontmatter schema change**.
- **Playbooks:**
  - `00-pipeline.md` — document the three layers and the new phase-boundary dispatches.
  - `30-construction.md` — after each wave: Master Agent monitoring + Auditor
    interrogation, before the wave is marked complete.
  - `40-qa.md` — rewritten with renumbered steps in this order: post-review dimensions
    incl. `mode=delta` → collate/dedupe → adversarial verification → **test-design
    debate** → test execution (with **execution debate** per wave) → fix loop →
    E2E verification → post evidence → AC matrix → **results debate** → **Tally
    reconciliation** → **Auditor final audit + interrogation** → **negotiation (if
    triggered)** → test-report approval → QA verdict/score → Critic verdict →
    **Supervisor audit over the super-context** → GATE G3. The spec intentionally avoids absolute step numbers; the playbook rewrite
    assigns them.
- **Rename sweep:** `master-supervisor` → `supervisor` across roles/, agents/, playbooks,
  protocol, docs, skills, templates, **and tests/** (`tests/install.test.sh` asserts the
  installed path `.aidd/framework/roles/master-supervisor.md` and will fail otherwise).
  `scripts/check-refs.sh` guards markdown references only — shell-script references are
  guarded by the framework test suite. `CHANGELOG.md` history intentionally keeps the
  old name.
- **Templates (new, in `core/templates/`):** `monitoring-report.md`,
  `interrogation-challenge.md`, `interrogation-response.md`, `auditor-verdict.md`,
  `negotiation-log.md`, `debate-record.md`, `snapshot.md`, `quality-baseline.md`,
  `context-delta.md`, `tally.md`.
- **ADRs (docs/design/decisions/):** 006 three-layer verification + DISPUTED blocking
  channel; 007 context snapshots; 008 delta review; 009 continuous test debate.
- **Docs:** `docs/three-layer-verification.md`, `docs/context-snapshots.md`; updates to
  `docs/supervision.md`, `docs/testing.md`, `docs/state-machine.md`, README.
- **Supervision protocol:** `core/protocol/supervision.md` phase checklists gain entries
  so the Supervisor audits that Layer 2 actually ran (monitoring notes present per wave,
  interrogation verdicts complete, budgets respected, debate records present).

## Testing strategy (framework's own suite)

- Schema fixtures: valid/invalid change-state with the new `audit` block and gates.
- Template lint: all nine new templates present and well-formed.
- `check-refs.sh` green after the rename sweep.
- `build-snapshot.sh` test against `tests/fixtures/sample-project/` (produces all four
  artifacts; idempotent; history accumulates).
- Hook test: snapshot hook fires and is silent/no-op outside an AIDD repo.
- Playbook conformance: grep-level assertions that the new steps are referenced from the
  playbooks (mirrors existing `refs.test.sh` style).

## Build order (four sequentially shippable stages — each usable once its predecessors ship)

1. **Snapshots** — script, protocol, hook, gitignore, role Inputs updates.
2. **Layer 2** — Master Agent + Auditor + Tally roles/agents, interrogation +
   negotiation protocols, Supervisor rename + super-context, schema `audit` block +
   gates (incl. `tally_reconciled`), `tally.md` template, ADR 006.
3. **Delta review** — `mode=delta`, consumes snapshot history; ADR 008.
4. **Test debate + Playwright MCP** — debate protocol, test-engineer updates, MCP
   execution path with script fallback; ADR 009.

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Dispatch cost: Layer 2 adds ~2 adjudicative dispatches per wave + several in QA | Budgets are hard (2 interrogation rounds, 2 negotiation exchanges, 6 debate exchanges); user explicitly chose precision over speed |
| Role confusion: Master Agent vs orchestrator vs Supervisor | Charters are disjoint by artifact class: orchestrator writes state files only; Master Agent writes monitoring/negotiation/debate artifacts only; Supervisor writes supervision reports + adjudication rulings only |
| Rename breaks references | `check-refs.sh` gate in CI; rename is one commit inside stage 2 |
| Deadlock loops | Every protocol ends in a terminal state: PROVEN, fix-loop defect, or forced-human; no unbounded retries anywhere |
| Playwright MCP absent on some runtimes | Explicit fallback to vendored `playwright-capture.mjs`; degradation recorded, never silent |
| Snapshot staleness after crash | Snapshots rebuilt on every resume; gates never pin snapshot hashes |

## Out of scope

- Jira write-back changes (stays OFF by default, per-run human approval).
- Any change to the Critic's role or verdict format.
- Live agent-to-agent messaging (rejected in favor of artifact rounds).
- BMAD planning-orchestrator integration (separate track if desired later).
