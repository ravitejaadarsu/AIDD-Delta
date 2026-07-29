# Evidence Capture

Canonical: `core/protocol/evidence.md`; role: `core/roles/evidence-capturer.md`.

- **Pre** (before any code): baseline Playwright screenshots/traces of every affected
  flow (from the PRD's flow table), CLI/API transcripts for non-UI flows, and benchmark
  runs (`core/templates/bench-capture.sh`).
- **Post** (after QA's fix loop + E2E): the same flows and benches again.
- `evidence/manifest.md` indexes every capture with checksums; the perf-budget table
  compares pre vs post against `architecture.md` budgets — regressions block delivery.
- The PR body links the before/after gallery, so reviewers *see* the change, not just
  read about it.
- Degradation is explicit: no Playwright → transcripts with a reason; no applicable
  bench → `na` with a reason. Nothing silently skipped.

Templates: `core/templates/playwright-capture.mjs` (chromium capture script) and
`core/templates/bench-capture.sh` (3-run wall-clock bench).
