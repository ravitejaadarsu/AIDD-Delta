---
id: D-006-perf-regression-quadratic-render
target: T-002-todo-remove-op
defect_class: perf-regression
injection_mode: command
visible_to: L1-review
injection: |
  python3 "${BENCH_REPO_ROOT}/bench/scripts/bench-patch.py" ./src/todo.py \
    --copy-from "${BENCH_REPO_ROOT}/bench/fixtures/injections/todo_perf_quadratic.py"
why_ordinary_review_misses_it: |
  The output is byte-identical for every input, so every existing test passes and no
  assertion can distinguish the two implementations. The diff replaces a comprehension with
  an explicit loop, which many reviewers read as more readable rather than worse, and at the
  fixture's scale (two items) the wall-clock difference is unmeasurable -- so even a
  benchmark run on the task's own data shows nothing.
  What changed is the complexity class: repeated string concatenation reallocates, so the
  cost is quadratic in the number of items. Catching it requires either reading for
  complexity rather than correctness, or running a bench at a scale nobody chose. That gap --
  correct output, wrong cost, invisible at test scale -- is why it is in the catalogue.
detection_signal: |
  A performance finding naming `src/todo.py` and the quadratic concatenation in
  `qa/findings-performance.md`, or a `performance-smoke` observation in `qa/tests/` or
  `audit/debate/performance-smoke.md`. A post-evidence bench that regressed beyond the
  `architecture.md` threshold (failing `perf_within_budget`) also counts, and the grader
  accepts either.
grader: |
  found=""
  if grep -rqsiE 'quadratic|O\(n\^?2\)|string concat' ./work/.aidd/changes/*/qa/findings*.md 2>/dev/null; then
    found="L1-review"
  fi
  if [ -z "${found}" ] && grep -rqsiE 'quadratic|O\(n\^?2\)|concat' ./work/.aidd/changes/*/qa/tests/performance-smoke.md ./work/.aidd/changes/*/audit/debate/performance-smoke.md 2>/dev/null; then
    found="L2-debate"
  fi
  if [ -z "${found}" ] && grep -qsiE 'quadratic|O\(n\^?2\)|string concatenation in a loop' ./driver.log; then
    found="L1-review"
  fi
  if [ -z "${found}" ]; then echo "ESCAPED"; exit 1; fi
  echo "CAUGHT-BY: ${found}"
---

# D-006 — same output, worse complexity

## What is injected

`render()` builds its result by repeated `+=`-style concatenation instead of `str.join`.

## Why it is in the catalogue

It is the corpus's example of a defect that **no assertion on output can find**, because the
output is correct. Only a reviewer reading for cost, or a bench at a scale the task never
mentions, sees it.

Note that this defect can legitimately be caught at two different layers, and the grader
records which one fired: a reviewer finding is `L1-review`, a `performance-smoke` observation
that reached the debate surface is `L2-debate`. That distinction is exactly the kind of thing
the report should show rather than average away.

## Reverting

Git checkout of `./src/todo.py`.
