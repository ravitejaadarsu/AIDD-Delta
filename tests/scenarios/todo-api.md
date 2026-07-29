# Dogfood Scenario — todo-api

Canned end-to-end exercise for AIDD Delta against `tests/fixtures/sample-project/`
(plus `sample-web/` for Playwright capture). Run it in BOTH modes before a release.

## Setup

1. Copy `tests/fixtures/sample-project/` to a scratch dir; `git init`; commit.
2. Install AIDD (`install.sh`), run the Master phase (constitution: python3/unittest,
   `python3 tests/test_todo.py` as the test command).

## Intent

> Add a `complete(items, index)` operation to the todo module: marks the item done,
> renders done items with a "[x] " prefix, rejects out-of-range indexes.

## Expected artifact checklist

- [ ] `intent.md` — clarifying questions table filled; zero open BLOCKING
- [ ] `prd.md` — ≥3 testable ACs (complete marks; render prefix; range error)
- [ ] `arch-candidates/` — 3 lens candidates + 3 scorecards; `architecture.md` cites winner
- [ ] `epic.md` — ≥2 stories, disjoint ownership, waves
- [ ] `stories/ST-*.md` — schema-valid frontmatter; Builder Reports show failing-before-green
- [ ] `pre-review/` — 4 dimension files; CRITICALs resolved before G2
- [ ] `evidence/pre/` + `evidence/post/` — CLI transcripts (sample-project) AND, when run
      against sample-web (`serve.sh` + templates/playwright-capture.mjs), screenshots
- [ ] `qa/findings-*.md` (5) + `qa/security-report.md` + `qa/verdicts.md` + funnel counts
- [ ] `qa/verification-report.md` — clean-state runs; mutation `na` reason (no tool) OK
- [ ] `ac-matrix.md` — every AC PASS with executed evidence
- [ ] `supervision/` — per-phase reports, all COMPLIANT; `audit.log` populated
- [ ] `delivery/` — traceability.mmd, pr-description.md, delivery-report.md with scores
- [ ] gates ledger — G1/G2/G3 entries with sha256 (auto in take-care, human in let-me-look)
- [ ] `learnings.md` — retro appended
- [ ] `dashboard.html` — reflects final state
- [ ] Both state files schema-validate at every checkpoint
