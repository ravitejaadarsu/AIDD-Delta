# Phase: Construction

Purpose: implement every story via strict TDD, in parallel waves, with baseline evidence
captured first.

## Steps

1. **Step 0 — pre evidence**: dispatch Evidence Capturer (`../roles/evidence-capturer.md`)
   with `stage: pre` over the PRD's affected-flows table + bench commands →
   `evidence/pre/` + manifest rows. Blocks wave 1 until complete.
2. For each wave in `epic.md` order:
   a. Fan out Builder (`../roles/builder.md`) for the wave's stories (cap 4).
      Sequential fallback: story-id order.
   b. As each returns, run the **TDD evidence check**: Builder Report must show
      (i) failing-test evidence, then (ii) green evidence, plus (iii) `git diff --stat`
      confined to the ownership set. Violation → story back to `ready`, ONE re-dispatch
      with the violation named.
   c. **Wave integration check** (orchestrator): run canonical build + full test suite.
      Red → Build Fixer (`../roles/build-fixer.md`), max 3 attempts, then blocked path.
3. After the final wave (incl. seam stories): full integration check again; set
   `quality_gates.tests_green`.
4. **Supervisor audit**.

## Blocked ladder (per story)

fresh re-dispatch → Architect scoped re-plan (ADR amendment; G2 → stale; delta stories
if needed) → human escalation. A blocked story blocks only its dependents.

## Exit checklist

- [ ] every story `done` with TDD evidence
- [ ] full build + suite green (evidence blocks)
- [ ] all diffs within ownership sets
- [ ] evidence/pre populated (or explicit `na` rows)
