# Phase: Delivery

Purpose: a merged-ready PR — reviewed, evidenced, traceable — with CI. Never merges.

## Steps

Phase boundary: rebuild the snapshot pack
(`bash .aidd/framework/scripts/build-snapshot.sh pre-delivery` per
`../protocol/context-snapshots.md`) before Step 1.

1. In parallel (sequential fallback: Doc Writer first):
   - Doc Writer (`../roles/doc-writer.md`) → docs/README/CHANGELOG edits +
     `delivery/docs-notes.md`.
   - Delivery Agent (`../roles/delivery-agent.md`) prep: rebase on default branch
     (non-trivial conflicts escalate to human in BOTH modes), story-grouped conventional
     commits, traceability graph (`templates/traceability.mmd` pattern) →
     `delivery/traceability.mmd`.
2. Delivery Agent: ensure CI workflow exists (adapt `templates/ci-workflow.yml` with the
   canonical commands) — commit if new.
3. Assemble PR body from `templates/pr-description.md`: verdict table, findings funnel,
   assumptions, AC matrix summary, evidence links, supervision summary, traceability.
4. Push branch; open PR (`gh pr create`); watch CI (poll, bounded 30 min).
   CI red → Build Fixer (max 2 attempts, re-push, re-watch) → exhausted = human
   escalation with logs.
5. Optional Jira write-back per `../protocol/jira-sync.md` (config + per-run approval).
6. **Supervisor final session report** → `supervision/final-report.md`.
7. Write `delivery/delivery-report.md`: per-phase verdicts/scores + funnel + links.
   Mark phase complete; global `changes.<id>` stays `in_progress` until retro.

## Scoring (orchestrator, rule-driven)

Per-phase verdict: FAIL (exit criterion unmet / open CONFIRMED CRITICAL / budget
exhausted) · CONCERNS (met with compromises: waivers, low-confidence assumptions,
forced-wave fallback, HIGH advisories, coverage in floor band, backflow) · PASS.
Score: 100 − deductions — CONFIRMED CRITICAL open −40 · AC FAIL at phase end −40 ·
backflow −15 · perf regression −15 · waiver −10 · missing evidence −10 · supervision
violation −10 · fix-loop iteration beyond first −5 · CONFIRMED HIGH fixed −5 ·
PLAUSIBLE HIGH −5 · ownership/TDD re-dispatch −5 · low-confidence assumption −3 ·
other advisory −2 · coverage below target −1/point. Floor 0.
Rollup: final verdict = worst phase; final score = 0.15·inception + 0.30·construction +
0.40·qa + 0.15·delivery.

## Exit checklist

- [ ] PR open, CI green, body embeds verdict/funnel/AC/evidence/supervision
- [ ] docs + changelog updated; samples verified
- [ ] delivery report written
