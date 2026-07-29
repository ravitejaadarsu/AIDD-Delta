# Phase: Inception

Purpose: intent → approved PRD → judged architecture → parallel-safe stories, reviewed
against the live codebase BEFORE any code.

## Steps

1. **Clarify** — dispatch Product Analyst (`../roles/product-analyst.md`), stage 1:
   `questions.md` section inside `intent.md`. Resolve per mode
   (`../protocol/autonomy-modes.md`). Zero open BLOCKING questions may remain.
2. **PRD** — Product Analyst stage 2 → `prd.md` (testable ACs with ids; Jira ACs imported
   per `../protocol/jira-sync.md`; affected-flows table for evidence capture).
3. **GATE G1** (`g1_prd`) per `../protocol/gates.md`.
4. **Architecture candidates** — dispatch Architect (`../roles/architect.md`) three times
   in parallel with lenses `simplicity-first`, `scalability-first`, `risk-first` →
   `arch-candidates/<lens>.md`. Fallback order: as listed.
5. **Judge panel** — dispatch Arch Judge (`../roles/arch-judge.md`) ×3 in parallel →
   `arch-candidates/scorecard-<n>.md`. Majority winner (sum of ranks).
6. **Synthesis** — Architect synthesis run merges winner + grafts best non-winner ideas →
   `architecture.md` with **Verification Commands** (orchestrator dry-probes each exists;
   broken → bounce once) and **Bench Commands & budgets**.
7. **Epic** — Epic Scoper (`../roles/epic-scoper.md`) → `epic.md`. Orchestrator runs the
   mechanical disjointness check (`../protocol/file-scope.md`).
8. **Stories** — fan out Story Author (`../roles/story-author.md`), one per story (cap 6).
   Orchestrator lints each story file: required sections + schema-valid frontmatter.
9. **Pre-implementation review** — fan out Reviewer (`../roles/reviewer.md`) with
   `mode: pre`, dimensions: feasibility, pattern-fit, coupling-risk, test-strategy →
   `pre-review/<dimension>.md`. CRITICAL findings must be resolved (artifact revised) or
   explicitly waived by the human; log resolutions.
10. **Supervisor audit** → then **GATE G2** (`g2_plan`).

## Exit checklist

- [ ] G1 + G2 approved (ledger entries with hashes)
- [ ] zero open BLOCKING questions; assumptions logged
- [ ] judge scorecards present; synthesis cites winner
- [ ] verification commands probed OK
- [ ] ownership matrix disjoint per wave (or CONCERNS recorded)
- [ ] every story file lints; pre-review CRITICALs resolved/waived
