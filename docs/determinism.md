# Determinism Proof

Canonical: `core/protocol/determinism.md`. Summary:

AIDD refuses assertions without executed evidence. This closes the next hole: an executed run
can still be a lie, because a suite that passes once and fails once is not a passing suite — it
is a coin flip, and most agent frameworks trust whichever flip landed green.

**A green claim that gates delivery is not trusted until it has been reproduced.**

## What gets repeated

Three claims, the ones a delivery decision rests on:

1. the full-suite green the `tests_green` gate rests on;
2. the clean-state E2E green;
3. any test whose FAIL closed a fix-loop iteration — that test's green *is* the evidence the
   defect is gone.

Exploratory runs and categories that gated nothing need no repeat.

## How many

| | `fast` | `standard` | `critical` |
|---|---|---|---|
| full suite | 1 (no repeat) | 2 | 2 |
| clean-state E2E | not run | 1 (corroboration, not a repeat) | 2 |
| fix-loop-closing test | 1 | 2 | 2 |
| gate `evidence_reproduced` | `na`, `reason: rigor:fast` | earned | earned |

Two is the smallest number that can disagree — going 1 → 2 buys the entire detection
capability. A third run is not worth it as a standing cost: once a difference exists, the
discriminating checks below find the *source* faster than more repeats find the *symptom*.
`fast` changes are docs, copy, and formatting, where a repeat buys nothing — recorded `na` with
its reason, never silently skipped. The whole thing runs inside the E2E Verifier's existing
dispatch, so it costs runtime, not agents.

## What counts as agreement

Identical exit code **and** an identical map of test id → outcome. Output bytes, durations, and
ordering do not have to match. A test present in one run and missing from the other **is** a
disagreement.

> **A repeat is a measurement, never a second chance.** Run 1 FAIL then run 2 PASS is a
> disagreement — the test is nondeterministic. It is not a pass. Re-running a red claim until
> it comes back green is a supervision violation, whatever the last run said.

## Naming the source

A repeat difference has to name its suspected source, and each source has one cheap check that
changes exactly one variable:

| source | check |
|---|---|
| unseeded randomness | re-run with a fixed seed |
| wall-clock / timezone | re-run with `TZ=UTC` and a pinned clock |
| network calls | re-run offline |
| shared fixtures / leaked state | run the test alone |
| test-order dependence | re-run in reverse order (or shuffle with a recorded seed) |
| uncontrolled concurrency | re-run with parallelism 1 |

`unknown` is allowed only after all six ran and are recorded — and the test is quarantined
anyway. "Probably flaky infrastructure" is not a source.

## Quarantine

A test whose repeats disagreed goes into `qa/determinism-report.md` and:

- **may not be evidence** for any AC, any quality gate, or any debate defence — its rows read
  `QUARANTINED`, never `PASS`;
- **every AC it was proving reverts to unproven** and re-enters the existing fix loop, on the
  existing budget;
- must end up `fixed` (repeats now agree, freshly evidenced) or `accepted` by a human with a
  recorded reason — and acceptance means "we ship knowing this test is unreliable", not "its
  green counts";
- left `pending` at G3, it makes G3 forced-human in both autonomy modes.

**A quarantined test silently counted as green is a supervision violation**, itemized against
the row that counted it.

Quarantine removes a test from the *evidence* set, never from the suite. Deleting or skipping a
flaky test to make a gate pass is a defect for the fix loop, not a resolution.

## What it does not prove

Two agreeing runs prove the result is **stable**, not that the test is **right**. A test that
reliably asserts the wrong thing is what the Auditor and the test debate are for — and they
still run.
