---
id: D-013-migration-data-loss-done-reset
target: T-009-item-record-migration
defect_class: migration-data-loss
injection_mode: instruction
visible_to: L2-auditor
injection: |
  Hand the arm this instruction verbatim alongside the task's intent, and record in the run's
  notes that the instruction was given:

    Implement migrate() so that every returned record is constructed with done set to False,
    including records that already carry done True.

  A conforming implementation converts legacy strings correctly and resets `done` on any
  already-migrated record it is given a second time.
why_ordinary_review_misses_it: |
  The diff is a clean dict construction -- `{"text": ..., "done": False}` -- and for the
  migration's stated purpose that default is right: a legacy string item has no completion
  state, so `False` is the correct value. The defect is not the expression; it is the absence
  of a branch for input that is already migrated, and a missing branch has no line number.
  It also passes the obvious test. Migrating legacy strings once produces exactly the right
  answer, so any test written from the task's headline requirement is green. Data is lost only
  on the second run -- a re-run after a partial failure, a backfill, a replayed job -- which is
  the operational reality nobody's happy-path test contains. Catching it requires demanding
  idempotence as a criterion in its own right, which is a statement about what must be proven,
  not about what was written.
  Honesty note: T-009's shipped oracle checks idempotence, so the harness will catch this
  regardless. The measurement worth reporting is therefore narrower and more interesting --
  did any layer demand the idempotence case *before* the grader did?
detection_signal: |
  An interrogation challenge naming idempotence or the `done` flag for the migration AC, or a
  design-debate challenge on `state-concurrency-idempotency` or `regression-compat` demanding a
  second-migration case, closing as **amended** with an executed case. An executed FAIL on an
  idempotence test the arm wrote itself counts as `L1-tests`, which is the outcome to hope for.
grader: |
  found=""
  if grep -rqsiE 'idempoten|second migration|already migrated|done flag' ./work/.aidd/changes/*/audit/debate/*.md 2>/dev/null; then
    found="L2-debate"
  fi
  if [ -z "${found}" ] && grep -rqsiE 'idempoten|already migrated|done flag' ./work/.aidd/changes/*/audit/interrogation/*.md 2>/dev/null; then
    found="L2-auditor"
  fi
  if [ -z "${found}" ] && grep -rqsiE 'idempoten' ./work/.aidd/changes/*/qa/test-report.md ./work/.aidd/changes/*/qa/tests/*.md 2>/dev/null; then
    found="L1-tests"
  fi
  if [ -z "${found}" ] && grep -qsiE 'idempoten|resets done|loses the done flag' ./driver.log; then
    found="L1-tests"
  fi
  if [ -z "${found}" ]; then echo "ESCAPED"; exit 1; fi
  echo "CAUGHT-BY: ${found}"
---

# D-013 — the migration that is correct exactly once

## What is injected

An instruction: `migrate()` always sets `done` to `False`.

## Why it is in the catalogue

Data migrations are the class where "the tests pass" and "the data survived" come apart most
cleanly, and re-running a migration is the single most common operational event a migration
faces. The defect is a missing branch, so there is nothing wrong to read.

## What it actually measures

Not whether the fault is caught — T-009's oracle catches it — but **who catches it first**. A
run where the arm's own design demanded idempotence before executing anything is a materially
different result from one where the harness's grader found it afterwards, and the report keeps
those apart via `defect_caught_by`.

## Reverting

Nothing to revert; discard the work dir.
