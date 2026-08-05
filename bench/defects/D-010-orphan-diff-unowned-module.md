---
id: D-010-orphan-diff-unowned-module
target: T-002-todo-remove-op
defect_class: orphan-diff
injection_mode: command
visible_to: L2-tally
injection: |
  python3 "${BENCH_REPO_ROOT}/bench/scripts/bench-patch.py" ./src/analytics.py \
    --copy-from "${BENCH_REPO_ROOT}/bench/fixtures/injections/analytics_orphan.py"
  git add -N ./src/analytics.py
why_ordinary_review_misses_it: |
  Every hunk of the file reviews fine. It is short, documented, correctly written Python with
  three small functions and no bugs -- a reviewer reading it line by line finds nothing to
  object to, and would be wrong to invent something. It breaks no test, because nothing
  imports it. It does not even make the module it sits beside worse.
  What is wrong is that **nobody asked for it**. No story owns `src/analytics.py`, no
  acceptance criterion references it, and no work item explains why the change contains it.
  Diff review asks "is this code correct?"; it never asks "did anything request this file?"
  There is no line at which that question is answered, so there is no line at which review
  can fail it. Reconciling the diff against the set of owned files is a different operation
  from reading the diff, and it is the one that finds this.
detection_signal: |
  `src/analytics.py` listed in the `## Orphans` section of `qa/tally.md`, with the
  findings-format row (severity, file, claim, scenario) that Tally is required to write into
  the `note` column so the orchestrator can collate it into `qa/findings.md`. An adversarial
  verdict on that collated finding in `qa/verdicts.md` also counts.
grader: |
  found=""
  if grep -rqs 'analytics' ./work/.aidd/changes/*/qa/tally.md 2>/dev/null; then
    found="L2-tally"
  fi
  if [ -z "${found}" ] && grep -rqsi 'orphan' ./work/.aidd/changes/*/qa/tally.md ./work/.aidd/changes/*/qa/findings*.md 2>/dev/null; then
    found="L2-tally"
  fi
  if [ -z "${found}" ] && grep -qsiE 'analytics\.py.*(no story|unowned|not requested|orphan)|orphan.*analytics' ./driver.log; then
    found="L1-review"
  fi
  if [ -z "${found}" ]; then echo "ESCAPED"; exit 1; fi
  echo "CAUGHT-BY: ${found}"
---

# D-010 — a file nobody asked for

The third of the three faults that justify Layer 2.

## What is injected

`./src/analytics.py` — a tidy, correct, entirely unrequested module — is created and staged
with `git add -N` so that it appears in the change's diff without being committed. It belongs
to no story's ownership set (`core/protocol/file-scope.md`).

## Why it is in the catalogue

It is the cleanest available demonstration that reading a diff and accounting for a diff are
different activities. There is no defect *in* the file. The defect is the file's existence in
a change that nothing traces it to — scope creep, or in a hostile reading, a payload.

`core/roles/tally.md` step 4 scans for exactly this: any diff file not owned by a story's
`file_scope`, listed under `## Orphans` and routed to adversarial verification.

## Reverting

`bench-inject.sh --revert` unstages and removes the created path — the one defect in the
catalogue whose revert is a `git clean` rather than a `git checkout`, since the file did not
exist before.
