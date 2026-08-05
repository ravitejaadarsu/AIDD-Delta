# bench — the evidence harness

Canonical method: `bench/harness.md`. Reader-facing summary: `docs/benchmarks.md`.

AIDD Delta's biggest weakness is that it is **unproven**. This directory is the answer: a
reproducible corpus, an injected-defect catalogue, and scripts that measure defect
detection, token cost, and wall-clock against a no-verification baseline.

**There are no published results in this repository.** `bench/results/` ships with a
template and nothing else. Every number in a report has to come from a run somebody
actually performed on their own machine, and a cell nobody measured reads `not measured`.

## Layout

| Path | What it holds |
| --- | --- |
| `bench/tasks/` | The task corpus, one file per task, `T-NNN-<slug>.md` |
| `bench/defects/` | The injected-defect catalogue, `D-NNN-<slug>.md` |
| `bench/fixtures/` | Seed files a task's `setup` copies into its work dir |
| `bench/scripts/` | `bench-run.sh`, `bench-grade.sh`, `bench-inject.sh`, `bench-report.sh` |
| `bench/results/` | Run outputs. `TEMPLATE.md` is the report shape |
| `bench/harness.md` | The method: schemas, metrics, reps, anti-cheating rules |

## Offline quickstart (no network, no API key)

Every script has `--help`. This sequence touches no network and needs no credentials —
it exercises the harness mechanics and validates the whole corpus:

```bash
bash bench/scripts/bench-run.sh --help
bash bench/scripts/bench-run.sh --dry-run --offline
bash bench/scripts/bench-inject.sh --list
bash tests/bench.test.sh
```

`--dry-run` validates every task's frontmatter, enums, setup, pretest, acceptance, and
oracle mechanically, checks that each offline fixture exists on disk, and prints the plan it
*would* execute. It never invokes a model. That is what CI runs.

## Running a real task

The harness ships **no LLM and no API key**. Every arm is a command you supply:

```bash
export BENCH_AIDD_CMD='claude -p'        # the framework arm
export BENCH_BASELINE_CMD='claude -p'    # the control arm (no verification layers)

bash bench/scripts/bench-run.sh --task T-001-todo-complete-op --driver aidd --reps 3
bash bench/scripts/bench-grade.sh --run-dir bench/results/<run-id>/T-001-todo-complete-op/rep-1
bash bench/scripts/bench-report.sh --run-id <run-id>
```

The driver is invoked with the task's `intent` verbatim on stdin and in `BENCH_INTENT`, in
a clean work dir, with `BENCH_USAGE_FILE` pointing at the path where it should write its
token usage. Read `bench/harness.md` before publishing anything: **≥3 reps**, a **baseline
arm**, medians with ranges, and the anti-cheating rules are not optional.

## The defect catalogue at a glance

`visible_to` is the **hypothesis** about which layer should surface the fault;
`defect_caught_by` in the metrics is the **measurement**, and they are allowed to disagree.

| Defect | Class | Mode | Hypothesised layer |
| --- | --- | --- | --- |
| D-001 | logic-inversion | command | L1-tests (control) |
| D-002 | off-by-one | command | L1-tests |
| D-003 | contract-break | command | L1-tests |
| D-004 | silent-catch | command | L1-review |
| D-005 | secret-leak | command | L1-review (control) |
| D-006 | perf-regression | command | L1-review |
| D-007 | race | instruction | L2-debate |
| D-008 | mocked-proof | command | L2-auditor |
| D-009 | missing-ac-coverage | command | L2-tally |
| D-010 | orphan-diff | command | L2-tally |
| D-011 | auth-bypass | instruction | L2-auditor |
| D-012 | tenant-leak | instruction | L2-auditor |
| D-013 | migration-data-loss | instruction | L2-auditor |
| D-014 | missing-ac-coverage | command | L2-debate |
| D-015 | process-skip | instruction | L3-supervisor |

D-001 and D-005 are deliberate **positive controls** that Layer 1 should catch outright. A
catalogue in which every fault needs Layer 2 would be a catalogue built to flatter Layer 2.

D-008, D-009, and D-010 are the three faults that justify Layer 2, and each one states its
argument checkably rather than rhetorically: the mocked test stays green with the function
under test completely broken (demonstrated, see the defect file), the disabled test's absence
has no line number, and the unrequested file has no defect in it at all.

## Running a defect

```bash
bash bench/scripts/bench-inject.sh --defect D-008-mocked-proof-patched-add --list
bash bench/scripts/bench-inject.sh --defect D-008-mocked-proof-patched-add --apply --work-dir <dir>
# ... run the arm ...
bash bench/scripts/bench-inject.sh --defect D-008-mocked-proof-patched-add --revert --work-dir <dir>
```

Injection is git-based and reversible, and it refuses to run on a dirty tree. Defects whose
`injection_mode` is `instruction` are printed for a human to hand to the arm — the script
exits 2 rather than pretending to have applied them.

## Verifying and refreshing the pinned SHAs

Public-repo tasks pin a commit SHA and are cloned read-only at that SHA. `verified: true`
means only that the SHA was confirmed to exist by `git ls-remote` at pin time — it does not
mean the task was confirmed satisfiable there. Tasks whose pin could not be confirmed carry
`verified: false`, and honesty beats volume: a `false` stays `false` until somebody checks.

```bash
# Does a pin still exist?
git ls-remote https://github.com/<owner>/<repo> | grep <sha>

# Refresh a pin to the current default-branch tip
git ls-remote https://github.com/<owner>/<repo> HEAD

# Then confirm the task is still unsatisfied at the new pin
bash bench/scripts/bench-run.sh --task <id> --preflight
```

`--preflight` clones at the pin, runs `setup`, then runs `pretest`. `pretest` **must fail**:
that is the proof the task is not already done at that commit. If it passes, the task is
recorded `PRETEST-ALREADY-SATISFIED` and is not eligible for a published result until it is
refreshed or dropped.

## Why a baseline arm is mandatory

See `docs/design/decisions/014-benchmark-harness.md`. "Three-layer verification caught N
defects" is not a finding unless an arm with no verification layers ran the same defects
through the same graders. The baseline arm is that control, and the cost overhead it
establishes is a headline number, not a footnote.
