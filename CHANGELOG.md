# Changelog

All notable changes to AIDD Delta are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: SemVer.

## [Unreleased]

## [0.4.0] - 2026-08-06

### Added

- Rigor modes (ADR 010, `core/protocol/rigor-modes.md`): `fast` / `standard` / `critical`
  decide how much verification a change earns, selected by a **deterministic classifier**
  that matches the change's own evidence — path-pattern trigger tables for authn/authz,
  secrets/crypto, money, tenancy, migrations, PII, public API, concurrency and infra; a
  `fast` allow-list requiring every condition; everything else `standard`, with all three
  tie-breaks resolving upward. Escalation is **one-way and automatic** (`fast` → `standard`
  → `critical`), re-seeds the audit budgets, voids every `na` earned under the outgone
  mode, back-fills the steps the new mode requires, and sets the take-care escalation flag.
  Rigor is orthogonal to autonomy and never touches the floor. New `/aidd:rigor` command,
  `rigor` state block, and `docs/rigor-modes.md`.
- Deterministic dispatch (ADR 011, `core/protocol/dispatch.md`): a decision table covering
  every fan-out in all four phases — unit counts per rigor mode, ownership rule, dispatch
  mode, cap, and a deterministic order. The orchestrator resolves a step's plan **once**,
  records it in `supervision/audit.log`, and re-deciding it mid-step is a supervision
  VIOLATION. Parallelism requires provably pairwise-disjoint ownership sets; unproven means
  sequential, with no case-by-case reasoning.
- Command contract (ADR 012, `docs/command-contract.md`): every `/aidd:*` command is
  declared in a manifest (`core/scripts/aidd-commands.txt`) binding it to the protocol file
  it executes, enforced by a guard hook and `tests/manifest.test.sh`. Skills are not
  commands — a skill name used as a command is named as such rather than silently routed.
- Progress contract (ADR 013, `core/protocol/progress.md`): one fixed, machine-parseable
  line per completed step, a distinct BLOCKED/FAILED shape carrying its remediation, an
  explicit forbidden-output list (dispatch deliberation, re-litigation, playbook echoes,
  filler), and a five-line cap on gate asks. The dashboard gains a **Recent progress**
  section that replays those lines from change history.
- Benchmark harness (ADR 014, `bench/`): a reproducible corpus of **28 tasks** and a
  **15-defect** injection catalogue with a shared `defect_class` / `visible_to` vocabulary,
  runnable scripts, a metrics schema, and a report template. **No results are published** —
  `bench/results/` ships its template and nothing else, and the README says so.
- Capability tiers (ADR 015, `docs/capability-matrix.md`): Tier 1 Claude Code · Tier 2
  Codex CLI · Tier 3 any other agent CLI, with every capability stating a
  supported / degraded / unsupported value for all three tiers and a named degradation
  path. Every README claim is re-grounded as `[designed]` / `[measured]` / `[planned]`, and
  `tests/claims.test.sh` fails CI on a claim that outruns its evidence.
- Cost governance (ADR 016, `core/protocol/cost-governance.md`): a per-change budget seeded
  from the rigor mode (**derived, not measured** — the formula is printed and the numbers
  are labelled seeds), an append-only `cost/ledger.md` with one row per dispatch, a
  deterministic projection with a stated tie rule and lower-bound reporting for unmeasured
  classes, and three thresholds with three distinct behaviors — soft reports, hard STOPs and
  asks (forced-human in both autonomy modes), runaway aborts the dispatch and never silently
  retries. An `na` justified by cost is forbidden outright. New `aidd-cost.sh` (read-only by
  contract), `/aidd:cost`, `cost` state block, and `docs/cost-governance.md`.
- Escape analysis (ADR 017, `core/protocol/escape-analysis.md`): the backward-looking
  counter-metric. When a defect reaches production, a nine-row per-layer verdict table
  determines which layer should have caught it and why it did not — including the
  caught-then-dropped case — and produces a permanent regression test plus a diff-level
  protocol amendment that is **never auto-applied**. Escape rate and per-layer blindness are
  recorded in `.aidd/escapes/register.md`, always with numerator and denominator, and read
  `not measured` rather than `0%` when the window has no analyzed escape. New Escape Analyst
  role, `/aidd:escape`, `escapes` state block, and `docs/escape-analysis.md`.
- Determinism proof (ADR 018, `core/protocol/determinism.md`): a green claim that gates
  delivery is not trusted until it has been reproduced. Two runs for the three claim classes
  a delivery decision rests on, per rigor mode; agreement defined as identical exit code
  plus an identical test-id → outcome map; six nondeterminism sources each with one
  discriminating check. **A repeat is a measurement, never a second chance** — re-running a
  red claim until it comes back green is a supervision VIOLATION. Disagreeing repeats
  quarantine the test, which may never again stand as evidence for an AC, a gate, or a
  debate defence. New `determinism` state block and `docs/determinism.md`.
- Two mode-independent quality gates — `within_cost_budget` and `evidence_reproduced` —
  bringing the set to sixteen, and four new change-state blocks: `rigor`, `cost`,
  `determinism`, `escapes`.
- ADRs 010 (rigor modes), 011 (deterministic dispatch), 012 (command contract), 013
  (progress contract), 014 (benchmark harness), 015 (capability tiers), 016 (cost
  governance), 017 (escape analysis), 018 (determinism proof).

### Fixed

- CI had failed on every run since v0.2.0: `markdownlint-cli2` was installed unpinned, so a
  new upstream rule (MD060) failed a build nobody had changed, while local runs skipped the
  linter entirely and never saw it. The toolchain is now pinned (`MDLINT_VERSION` in
  `tests/run.sh`; both workflows install that exact version and CI asserts no drift), local
  runs fall back to `npx` at the same pinned version so local == CI, `AIDD_STRICT_LINT=1`
  fails instead of skipping a missing linter, and all 143 real violations are cleared.

## [0.3.0] - 2026-08-04

### Added

- Three-layer verification (ADR 006): a dedicated Layer 2 — Master Agent
  (`master-agent`, work-quality monitoring after every construction wave and every QA
  step batch), Auditor (`auditor`, per-AC interrogation via `core/protocol/interrogation.md`,
  dispatched after every construction wave and once as the QA final audit), and Tally
  (`tally`, reconciling every tracked work item — Jira tickets, PRD ACs, stories —
  against the diff, the tests, and pre/post evidence, once in QA) — sits between the
  Layer-1 workers and the renamed Supervisor (Layer 3). The blocking economy is amended:
  an AC that exits the interrogation → negotiation (`core/protocol/negotiation.md`) →
  Supervisor-adjudication ladder as DISPUTED, or is ruled DEFECT, blocks via the fix loop
  exactly like an executed test FAIL. Hard budgets: max 2 interrogation rounds per
  subject, max 2 negotiation exchanges per disputed AC, with a short-circuit path when
  the Master Agent's own monitoring already concurs the work is deficient.
- Repo-level context snapshots (ADR 007): a gitignored `.aidd/context/` pack
  (`snapshot.md`, `quality-baseline.md`) rebuilt at every phase boundary and Construction
  wave; every role reads it first instead of re-crawling the repo. The
  pre-implementation history pack — latest `pre-construction`, falling back to
  `pre-inception` — feeds the new delta review.
- Reviewer `mode=delta` (ADR 008): a third mode on the existing parameterized Reviewer,
  dispatched once in QA step 1 alongside the `mode=post` dimension fan-out, binding
  intent-fidelity, structure-fit, and sigma-regression against the pre-implementation
  pack (latest `pre-construction`, falling back to `pre-inception`) →
  `qa/findings-delta.md`.
- Continuous test debate (ADR 009, `core/protocol/test-debate.md`): test designs and
  results are contested on three surfaces of the QA testing pass — design (before any
  case executes), execution (as each category's results land), and results (over the
  consolidated report) — drawing from a shared pool of 6 exchanges per change (2/2/2 per
  surface). Disputed PASSes are re-proven live: where the host provides Playwright MCP,
  UI-facing flows are re-driven in a real browser with screenshots as evidence;
  otherwise the vendored `core/templates/playwright-capture.mjs` script runs the
  fallback, with the path taken always recorded explicitly. New
  `core/templates/debate-record.md`.
- Three new mode-independent quality gates — `auditor_approved`, `debate_complete`,
  `tally_reconciled` — and a new `audit` state block (`interrogation`, `negotiation`,
  `debate` budgets and counters) in the change-state schema.
- ADRs 006 (three-layer verification), 007 (context snapshots), 008 (delta review), 009
  (continuous test debate).

### Changed

- The Master Supervisor role is renamed to Supervisor (now Layer 3 of three-layer
  verification); beyond phase-compliance auditing it now also adjudicates any
  negotiation that exhausts its budget, ruling `PROVEN | DEFECT | UNRESOLVABLE` from the
  phase's super-context (ADR 005 amendment, ADR 006).

## [0.2.0]

### Added

- Governance & impact capabilities: `impact-analyst`
  (multi-lens blast-radius analysis, Inception + `/aidd:impact`), `independent-thinker`
  (counter-arguments before G2), and `critic` (consolidated APPROVE / APPROVE WITH
  CONDITIONS / REJECT verdict at G3 via the `critic_approved` gate). Security auditor
  gains a CWE/CVSS threat matrix; Retro gains a memory-health pass. `docs/impact-analysis.md`,
  `docs/governance.md`. Counts: 22 roles / 17 commands / 22 agents.
- Test Engineer role (`test-engineer`) — a team of senior testers that designs
  and executes an exhaustive test matrix (happy path, negative, boundary,
  impossible/abuse, API-contract, concurrency, regression, performance) per
  fix/story/implementation, writes the end-results file `qa/test-report.md`, feeds
  failures into the QA fix loop, and links the report into the story on approval
  (`g_test_report` gate). New `/aidd:test` command, `exhaustive_tests_passed`
  quality gate, and `docs/testing.md`.

## [0.1.0]

### Added

- Portable core: playbooks (pipeline, document, master, inception, construction, qa,
  delivery, retro), 18 agent role files, protocol specs, artifact templates, JSON Schemas.
- Claude Code plugin shell: slash commands, subagent registrations, skills, hooks.
- Universal `install.sh` (idempotent, AGENTS.md-patching) and `core/scripts/render-dashboard.sh`.
- Zero-dependency self-test suite (`tests/run.sh`) and GitHub Actions CI.
- Dual autonomy modes (`take-care`, `let-me-look`) with hash-bound gate ledger.
- Master Supervisor session auditing, adversarial review verification, Playwright +
  benchmark evidence capture, Jira AC matrix, mutation/security/perf quality gates,
  continuous-learning retro, live dashboard, traceability graph.
