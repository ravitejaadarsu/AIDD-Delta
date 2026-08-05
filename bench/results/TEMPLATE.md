# Benchmark run report — TEMPLATE

`bench-report.sh` copies this file to `bench/results/<run-id>/report.md` and replaces every
`<!-- BENCH:* -->` marker with a generated table. Committed as-is, it contains no numbers,
because this repository publishes no measured results.

## The `not measured` convention

**Every unmeasured cell in a generated report reads `not measured`. Never blank, never `0`,
never an estimate.** A statistic whose inputs are all `null` renders `not measured`, and any
derived metric that depends on it renders `not measured` too. If a report shows a number, a
run produced it; if it shows `not measured`, nobody measured it. There is no third state.

Token counts come only from the runtime's own usage output, written by the driver to
`BENCH_USAGE_FILE`. When that file is absent or unparseable, `usage_source` is
`not-measured`, the token fields stay `null`, and the row is flagged `NO-USAGE-DATA`.

## Run metadata

<!-- BENCH:RUN-META -->

Environment capture for this run is in `env.md` beside this file: UTC timestamp, `uname -a`,
the framework repo's `HEAD` and whether the tree was dirty, tool versions, the driver command,
and every `BENCH_*` variable with secret-looking names redacted. **A run made from a dirty
framework tree is disqualified from a published claim.**

## Per-task results

Medians with ranges, never a bare mean — LLM runs are stochastic. `UNDER-REPPED` marks any
task with fewer than 3 reps for an arm; those rows must not be cited.

<!-- BENCH:PER-TASK -->

Flag meanings:

- `UNDER-REPPED` — fewer than 3 reps. Not citable (`bench/harness.md`, repetitions).
- `SETUP-FAIL` — the task's `setup` block failed. Reported, never silently dropped.
- `PRETEST-ALREADY-SATISFIED` — the behaviour already existed at the pin, so the task proves
  nothing. Excluded from claims until it is re-pinned or dropped.
- `PRETEST-ERROR` — a precondition failed (missing file, missing symbol). Not a FAIL.
- `NO-USAGE-DATA` — the driver reported no token usage for at least one rep.

## Defects caught vs missed, by layer

`visible_to` in the catalogue is the hypothesis; the layer credited below is what actually
fired. They are allowed to disagree — that disagreement is a result, not an error.

<!-- BENCH:DEFECTS-BY-LAYER -->

A catch requires a **reported** detection: an artifact or transcript in which the arm said
what was wrong. A defect that merely made the task's oracle fail is an escape accompanied by
a failed task, not a catch.

D-015 (`process-skip`) is `NOT-APPLICABLE` to any arm with no verification dispatches to skip.
A layer that does not exist cannot fail to run, and cannot be credited with running either.

## Derived metrics

<!-- BENCH:DERIVED -->

`cost overhead vs baseline` and `wall-clock overhead vs baseline` read `not measured` whenever
the baseline arm produced no reps. **Without a baseline arm there is no comparative claim to
make** (ADR 014) — only an absolute one.

Wall-clock covers the driver invocation only. Setup, cloning, and grading are harness cost,
not arm cost, and are excluded by design.

## Anti-cheating checklist

Fill this in by hand for the run. An unchecked row invalidates the published result
(`bench/harness.md`).

| Rule | Upheld? | Note |
| --- | --- | --- |
| No task-specific prompts | not measured | |
| Identical intents across arms (byte-identical) | not measured | |
| Graders committed before the first rep | not measured | |
| No retry-until-pass; rep count fixed in advance | not measured | |
| Every attempted task published, including failures | not measured | |
| Corpus frozen before the first arm ran | not measured | |
| Baseline arm present for every comparative claim | not measured | |
| Harness cost (overhead vs baseline) reported | not measured | |
| Framework tree clean at run start | not measured | |

## Grade evidence

Every grade quotes the mandatory evidence-block format from `core/protocol/evidence.md` —
command, trimmed output, exit code, ISO-8601 UTC timestamp. A grade with no evidence block is
not a grade.

<!-- BENCH:EVIDENCE -->

## What this run does not show

State the limits explicitly. At minimum: which acceptance criteria the oracle did not cover
(some tasks say so in their `notes`), which tasks were excluded and why, which arms were not
run, and any deviation from the protocol in `bench/harness.md`.

not measured
