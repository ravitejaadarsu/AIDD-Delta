---
id: D-014-missing-ac-coverage-vacuous-assertion
target: T-006-extract-line-formatter
defect_class: missing-ac-coverage
injection_mode: command
visible_to: L2-debate
injection: |
  python3 "${BENCH_REPO_ROOT}/bench/scripts/bench-patch.py" ./tests/test_todo.py \
    --expect 'self.assertEqual(todo.render(["a", "b"]), "1. a\n2. b")' \
    --replace 'self.assertIsNotNone(todo.render(["a", "b"]))'
why_ordinary_review_misses_it: |
  The test still runs, still passes, and still reads as a test of `render`. `assertIsNotNone`
  is a real assertion from the same library, applied to the right call, with the right
  arguments -- there is nothing malformed to object to, and in a diff it looks like somebody
  loosened an over-specified string comparison, which is a change reviewers frequently approve
  and sometimes request.
  What it destroys is the only executed proof of T-006's central criterion: that the refactor
  leaves `render`'s output byte-identical. After the injection, `render` could return any
  non-empty value and the suite would stay green -- so a refactor that silently changed the
  numbering, the separator, or the spacing now has nothing standing against it. The fault is
  not in the assertion, it is in the mismatch between what the assertion proves and what the
  criterion claims. Only somebody asking "what does this case actually establish about the
  AC it is mapped to?" finds that, which is the design and execution debate surfaces' job.
detection_signal: |
  A debate row in `audit/debate/<category>.md` contesting the TC as proving nothing about the
  output-identical AC, closing as **amended** with the exact-string assertion restored and
  re-executed; or an interrogation challenge on that AC demanding the byte-identical proof,
  with the AC closing `DISPUTED` if the demand is not met.
grader: |
  found=""
  if grep -rqsiE 'assertIsNotNone|vacuous|proves nothing|does not assert' ./work/.aidd/changes/*/audit/debate/*.md 2>/dev/null; then
    found="L2-debate"
  fi
  if [ -z "${found}" ] && grep -rqsiE 'assertIsNotNone|byte-identical|exact (output|string)' ./work/.aidd/changes/*/audit/interrogation/*.md 2>/dev/null; then
    found="L2-auditor"
  fi
  if [ -z "${found}" ] && grep -rqsE 'GAP' ./work/.aidd/changes/*/qa/tally.md 2>/dev/null; then
    found="L2-tally"
  fi
  if [ -z "${found}" ] && grep -qsiE 'assertIsNotNone|assertion proves nothing|weakened assertion' ./driver.log; then
    found="L1-review"
  fi
  if [ -z "${found}" ]; then echo "ESCAPED"; exit 1; fi
  echo "CAUGHT-BY: ${found}"
---

# D-014 — the assertion that asserts nothing

## What is injected

`test_render`'s exact-output comparison becomes `assertIsNotNone`.

## Why it is in the catalogue

It is the counterpart to D-002. There, an off-by-one was caught instantly by an exact-string
assertion; here that same assertion is quietly replaced by one that cannot fail, and the fault
becomes undetectable by every layer that only consumes pass/fail results — the suite is green,
the case ran, and the report says PASS.

Pair the two in a report: D-002 caught and D-014 escaped, in the same arm, is a precise
statement about how much of that arm's confidence rests on assertions nobody audited.

## Why `L2-debate` rather than `L2-auditor`

The execution-debate surface exists for exactly this contest — "a PASS resting on a case that
does not prove the AC it claims" is one of the named grounds for a challenge in
`core/protocol/test-debate.md`. The Auditor's per-AC interrogation is the second path, and the
grader accepts either.

## Reverting

Git checkout of `./tests/test_todo.py`.
