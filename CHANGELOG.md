# Changelog

All notable changes to AIDD Delta are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: SemVer.

## [Unreleased]

### Added

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
