# Changelog

All notable changes to AIDD Delta are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: SemVer.

## [Unreleased]

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
