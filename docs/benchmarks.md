# Benchmarks

Canonical: `bench/harness.md`.

## No results are published yet — run it yourself

AIDD Delta ships a benchmark **harness**, not benchmark **results**. There are no measured
numbers in this repository, and there will be none until somebody performs runs and publishes
them with their environment attached. Anything you read here about defect detection, token
cost, or completion time is a description of what the harness measures — never a claim about
what it found.

This is deliberate. The framework's honest weakness is that it is unproven; the answer to
that is a method a stranger can run, not numbers a maintainer typed.

## What the harness measures

Three questions, each with a deterministic answer:

1. **Task completion.** 28 reproducible tasks across six classes (bugfix, feature, refactor,
   security, migration, docs) and five difficulty levels — from a one-word button-label change
   to a concurrency race, an auth-boundary check, and a data migration. Each task has an
   `oracle`: a committed command whose exit code is the grade. No task grades on "looks good".
2. **Defect detection by layer.** 15 injected defects, each tagged with the layer that
   *should* catch it — `L1-review`, `L1-tests`, `L2-auditor`, `L2-tally`, `L2-debate`,
   `L3-supervisor` — and each carrying an explicit, checkable argument for why ordinary diff
   review misses it. Three classes exist specifically to test whether Layer 2 earns its cost:
   `mocked-proof` (the test asserts on a mock, so the AC is unproven), `missing-ac-coverage`
   (no executed test maps to an AC), and `orphan-diff` (code no work item owns).
3. **Cost.** Tokens and wall-clock per task per repetition, and the derived numbers that
   matter: defect-detection rate, escape rate, cost per caught defect, and **cost overhead
   versus a baseline arm** — a single agent with no verification layers at all.

## How to run it

### Offline quickstart

No network, no API key, nothing to configure:

```bash
bash bench/scripts/bench-run.sh --dry-run --offline
bash bench/scripts/bench-inject.sh --list
bash tests/bench.test.sh
```

`--dry-run` validates every task mechanically — frontmatter keys, enum values, fixture
existence, non-empty setup/pretest/acceptance/oracle — and prints the plan it would execute
without invoking a model. That is what CI runs, so the harness itself stays honest even
though CI has no credentials.

### A real run

The harness ships no LLM. Every arm is a command you supply, and the same intent goes to all
of them:

```bash
export BENCH_AIDD_CMD='claude -p'        # the framework arm
export BENCH_BASELINE_CMD='claude -p'    # the control: one agent, no verification layers

bash bench/scripts/bench-run.sh --task T-001-todo-complete-op --driver baseline --reps 3
bash bench/scripts/bench-run.sh --task T-001-todo-complete-op --driver aidd --reps 3
bash bench/scripts/bench-report.sh --run-id <run-id>
```

Point `--driver external:<cmd>` at any other harness — AI-DLC, Superpowers, a bare agent CLI
— and it is measured on exactly the same terms: same intent in, same oracle out, same metrics
file.

## How to read a report

`bench/results/TEMPLATE.md` is the shape. Four things to check before you believe a number:

- **`not measured` means not measured.** Never blank, never zero. If a token count is
  missing because the runtime reported no usage, the cell says so and the derived cost
  metrics that depend on it say so too.
- **Rep counts.** Fewer than three reps per task per arm is marked `UNDER-REPPED`. LLM runs
  are stochastic; one rep is an anecdote. Medians with ranges, never a bare mean.
- **The baseline column.** Any comparative claim without a populated baseline arm is not a
  comparison. The report's derived-metrics table leaves the overhead rows `not measured`
  when the baseline arm is absent.
- **The anti-cheating checklist.** Identical intents across arms, graders committed before
  runs, no retry-until-pass, failures published, the framework tree clean. The report has a
  row per rule; an unchecked row invalidates the run.

Every grade quotes an evidence block in the framework's mandatory format
(`core/protocol/evidence.md`): the command, its trimmed output, its exit code, and an
ISO-8601 UTC timestamp. A grade with no evidence block is not a grade.

## Honesty notes worth reading before you cite anything

- **`verified: true` on a task means one thing only:** the pinned commit SHA was confirmed to
  exist by `git ls-remote` at pin time. It does not mean the task was confirmed *satisfiable*
  at that commit. Each task's `pretest` decides that at run time, on your machine — and a
  `pretest` that passes means the behaviour already exists, so the task is recorded
  `PRETEST-ALREADY-SATISFIED` and excluded from published results until it is re-pinned.
- **Public repositories move.** The corpus tells you how to re-verify and refresh every pin
  (`bench/README.md`).
- **Some criteria are deliberately not machine-graded** — where a criterion needs a human to
  read the diff, the task says so and the report says which criteria the oracle actually
  covered.
- **Setup and grading time are excluded** from an arm's wall-clock. Cloning a Rust repository
  is the harness's cost, not the agent's.

See also: [ADR 014](design/decisions/014-benchmark-harness.md),
[Three-Layer Verification](three-layer-verification.md), [Testing](testing.md).
