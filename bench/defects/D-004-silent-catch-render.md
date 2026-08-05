---
id: D-004-silent-catch-render
target: T-005-render-embedded-newline
defect_class: silent-catch
injection_mode: command
visible_to: L1-review
injection: |
  python3 "${BENCH_REPO_ROOT}/bench/scripts/bench-patch.py" ./src/todo.py \
    --copy-from "${BENCH_REPO_ROOT}/bench/fixtures/injections/todo_silent_catch.py"
why_ordinary_review_misses_it: |
  Nothing fails. `render()` still returns the right string for every input the existing
  suite uses, so the whole suite is green and stays green -- there is no executed FAIL for
  any layer to route. The diff shows a `try/except` with a comment saying "never let a
  rendering problem take down the caller", which reads as defensive engineering, and
  reviewers routinely approve exactly that.
  What it actually does is convert every future rendering bug into an empty string: a caller
  that renders a malformed item now sees an empty list instead of an error, indistinguishable
  from having no items at all. That consequence is not in the diff; it is in the space of
  inputs nobody tested. This is why the defect is tagged `L1-review` rather than `L1-tests` --
  no test can catch it, because there is nothing that fails.
detection_signal: |
  A reviewer finding, in `qa/findings-correctness.md` or `qa/findings-delta.md`, that names
  `src/todo.py` and the bare `except` as swallowing errors, surviving adversarial
  verification as CONFIRMED or PLAUSIBLE in `qa/verdicts.md`. In a non-AIDD arm, the same
  observation anywhere in the driver transcript.
grader: |
  found=""
  if grep -rqsiE 'except|swallow|silent' ./work/.aidd/changes/*/qa/findings*.md 2>/dev/null &&
     grep -rqs 'todo.py' ./work/.aidd/changes/*/qa/findings*.md 2>/dev/null; then
    found="L1-review"
  fi
  if [ -z "${found}" ] && grep -qsiE 'bare except|swallow(s|ed|ing)? (the )?error|silently returns' ./driver.log; then
    found="L1-review"
  fi
  if [ -z "${found}" ]; then echo "ESCAPED"; exit 1; fi
  echo "CAUGHT-BY: ${found}"
---

# D-004 — the defensive catch that hides everything

## What is injected

`render()`'s body is wrapped in `try/except Exception: return ""`, with a comment justifying
it.

## Why it is in the catalogue

It is the first defect in the catalogue that **no test can catch**, because nothing fails.
Only a reader who asks "what does this hide?" finds it, which makes it the honest test of
whether a review layer is doing more than pattern-matching for obvious mistakes.

It is also the defect most likely to be *argued for* rather than fixed, which makes the
adversarial-verification step (`qa/verdicts.md`) part of the signal: a finding that gets
REFUTED here is itself a result worth reporting.

## Reverting

Git checkout of `./src/todo.py`.
