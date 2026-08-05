# AIDD Delta Benchmark Harness — Method

Canonical method document for the benchmark. `docs/benchmarks.md` is the reader-facing
summary; this file is the contract the scripts implement and the tests assert.

**Nothing in this repository claims a measured result.** The corpus, the defect catalogue,
the scripts, and the report template ship empty of numbers on purpose. Every results file
is either a template or the output of a run somebody actually performed. A cell nobody
measured reads `not measured` — never blank, never `0`.

## What the harness is for

AIDD Delta asserts precision. This harness exists so the assertion can be checked by a
third party, on their own hardware, against code they can read:

1. **Does the pipeline complete real tasks?** — the task corpus (`bench/tasks/`).
2. **Does three-layer verification catch defects ordinary code review misses?** — the
   defect catalogue (`bench/defects/`).
3. **What does that cost?** — tokens, wall-clock, and the derived cost-per-caught-defect,
   always against a **baseline arm** (single agent, no verification layers).

## Vocabulary

| Term | Meaning |
| --- | --- |
| arm | One driver under test in a comparison — `aidd`, `baseline`, or `external:<cmd>` |
| baseline arm | A single agent, one pass, no Layer-1/2/3 verification. The control |
| driver | The command the harness invokes to actually do the task |
| task | One reproducible change request with a deterministic oracle |
| defect | One injected fault plus the layer that should surface it |
| rep | One execution of one task by one arm. LLM runs are stochastic — reps matter |
| run | One invocation of `bench-run.sh`, identified by a run-id |
| oracle | The deterministic pass/fail decision procedure for a task |
| pretest | The command that must **fail** before a run, proving the task is not already done |

## Task corpus schema

One file per task at `bench/tasks/T-NNN-<slug>.md`. The `id` equals the filename without
`.md`. Frontmatter is a strict YAML subset — plain scalars and `|` block scalars only, the
same subset `core/scripts/aidd-validate.py` accepts for state files (ADR 002). Every key
below is **required**; the bench suite fails the whole test run if one is missing or carries
a value outside its enum.

| Key | Type | Rule |
| --- | --- | --- |
| `id` | scalar | `T-NNN-<slug>`, unique, equals the filename stem |
| `title` | scalar | One line, human-readable |
| `repo` | scalar | `local:tests/fixtures/<name>` or an `https://` repo URL |
| `commit` | scalar | 40-hex commit SHA, or `local` for a fixture task |
| `verified` | scalar | `true` only when the SHA's existence was confirmed (see below) |
| `class` | enum | `bugfix` / `feature` / `refactor` / `security` / `migration` / `docs` |
| `expected_rigor` | enum | `fast` / `standard` / `critical` — the rigor-mode vocabulary |
| `difficulty` | int | 1 (a copy change) to 5 (a race, an auth boundary, a data migration) |
| `token_budget_hint` | int | Advisory ceiling in tokens. Not a pass/fail criterion |
| `setup` | block | Exact commands, self-contained, run in an empty work dir |
| `intent` | scalar | The verbatim one-line intent handed to **every** arm |
| `pretest` | block | Must exit non-zero at the pinned SHA. Exit 0 means UNSATISFIABLE |
| `acceptance` | block | Objective criteria — commands plus expected outcomes |
| `oracle` | block | The deterministic grader. Exit 0 is PASS, non-zero is FAIL |
| `notes` | block | Caveats, provenance, why the task is shaped this way |

### Execution contract for the command blocks

- `setup`, `pretest`, `acceptance`, and `oracle` are `bash -euo pipefail` scripts.
- Each block runs in its **own** shell, so a `cd` in `setup` does not persist. A task that
  works inside a cloned repo has every block `cd` into it.
- CWD is the run's work directory (`<run-dir>/work/`), empty before `setup`.
- `BENCH_REPO_ROOT` is exported and points at this repository's root. Task blocks copy
  fixtures out of it; they never write into it.
- Paths inside the work dir are written `./x/y` — relative, and explicit that they resolve
  against the work dir rather than the framework repo.
- `oracle` is what decides PASS/FAIL. `acceptance` is the human-readable statement of the
  same thing; where they disagree, the oracle is a bug and gets fixed before any run.

### `pretest` exit codes

`pretest` is the acceptance assertion run **before** the arm touches anything. Its exit code
is a three-way answer, not a boolean:

| Exit | Meaning | `pretest_status` |
| --- | --- | --- |
| 0 | The behaviour is already present. The task proves nothing here | `already-satisfied` |
| 1 | The behaviour is absent. This is the required state | `unsatisfied-as-required` |
| ≥2 | A precondition failed (missing file, missing symbol, broken setup) | `error` |

A task whose `pretest` needs a precondition writes it explicitly, e.g.
`grep -q "def resolve_redirects" ./path || exit 3`, so a repo that drifted under the pin is
reported as an `error` rather than being mistaken for an unsatisfied task. Only
`unsatisfied-as-required` makes a rep eligible for a published result.

### Offline tasks

A task whose `repo` starts `local:` runs with no network and no API keys for everything
except the driver itself, and `bench-run.sh --dry-run --offline` validates it end to end.
At least six such tasks are required; the suite asserts it. They are the corpus's
reproducibility floor: anybody can exercise the harness mechanics without credentials.

### Pinned SHAs and the meaning of `verified`

Public-repo tasks are cloned **read-only at the pinned SHA** —
`git clone --no-checkout --filter=blob:none` followed by `git checkout --detach <sha>`. The
harness never pushes, never opens a PR, and never writes outside its work dir.

`verified: true` means exactly one thing: the SHA was confirmed to exist in that repository
by `git ls-remote` at pin time. It does **not** mean the task was confirmed satisfiable at
that commit — that is what `pretest` is for, and it is checked at run time, per run, on the
runner's own machine.

To verify or refresh a pin:

```bash
git ls-remote https://github.com/<owner>/<repo> HEAD     # current default-branch tip
git ls-remote https://github.com/<owner>/<repo> | grep <sha>   # confirm a pin still exists
bash bench/scripts/bench-run.sh --task <id> --preflight  # clone, run setup + pretest
```

`--preflight` is the honest gate on a public-repo task: it clones at the pin, runs `setup`,
then runs `pretest`. A `pretest` that exits 0 means the behavior the task asks for is
already present at that commit, so the task is recorded `PRETEST-ALREADY-SATISFIED` and is
**not** eligible for a published result until it is refreshed or dropped. A `setup` that
fails is recorded `SETUP-FAIL`. Neither is silently skipped.

## Defect catalogue schema

One file per defect at `bench/defects/D-NNN-<slug>.md`, same YAML subset, all keys
required.

| Key | Type | Rule |
| --- | --- | --- |
| `id` | scalar | `D-NNN-<slug>`, unique, equals the filename stem |
| `target` | scalar | A task `id` in `bench/tasks/`, or `local:tests/fixtures/<name>` |
| `defect_class` | enum | See the class list below |
| `injection_mode` | enum | `command` (mechanically applied) or `instruction` (given to the arm) |
| `visible_to` | list | Comma-separated layer tokens — which layer *should* catch it |
| `injection` | block | The exact command, or the precise instruction |
| `why_ordinary_review_misses_it` | block | The honest argument. Non-empty, and not rhetoric |
| `detection_signal` | block | The exact artifact plus the row that surfaces it |
| `grader` | block | Deterministic check — exit 0 means the defect was caught |

`defect_class` enum: `auth-bypass`, `tenant-leak`, `off-by-one`, `race`, `silent-catch`,
`mocked-proof`, `missing-ac-coverage`, `perf-regression`, `contract-break`,
`migration-data-loss`, `secret-leak`, `logic-inversion`, `orphan-diff`, `process-skip`.

The last two extend the original twelve, and both extensions are load-bearing:

- `orphan-diff` — code in the diff that no work item owns. Nothing in the original list
  described it, and it is one of the three faults that justify Layer 2 existing.
- `process-skip` — a required dispatch that never happened. Without it the catalogue can
  exercise Layers 1 and 2 but never Layer 3, whose whole subject is process compliance.

`visible_to` enum: `L1-review`, `L1-tests`, `L2-auditor`, `L2-tally`, `L2-debate`,
`L3-supervisor`.

### The three defects that justify Layer 2

An ordinary diff review reads the change. These three faults are invisible to a reader of
the change, because the change itself is unremarkable — what is wrong is the *relationship*
between the change, the tests, and the acceptance criteria:

1. **`mocked-proof`** — the test passes because it asserts on a mock of the very unit under
   test. The diff looks like a test being added. The suite is green. The AC is unproven.
   Caught by the Auditor's interrogation (`core/protocol/interrogation.md`), which demands
   the real flow and rejects a re-cite.
2. **`missing-ac-coverage`** — no executed test maps to an AC. Nothing in the diff is
   *wrong*; something is absent, and absence has no line number for a reviewer to land on.
   Caught by Tally's `GAP` row (`core/roles/tally.md`) and the AC matrix.
3. **`orphan-diff`** — a file in the diff that no story's ownership set claims. Each
   individual hunk reviews fine. Nobody asked for the file. Caught by Tally's `## Orphans`
   section.

The catalogue states this per defect, checkably: `detection_signal` names the artifact and
the row, and `grader` is the command that decides whether that row exists.

## Run identity, layout, and metrics

Run-id scheme: `<UTC-timestamp>-<driver>-<corpus-tag>`, e.g.
`20260806T101500Z-aidd-offline`. Timestamps are ISO-8601 UTC, basic format, `Z`-suffixed.

```text
bench/results/<run-id>/
  env.md                      environment capture (see below)
  report.md                   written by bench-report.sh from TEMPLATE.md
  <task-id>/
    rep-1/
      metrics.json            the machine record — schema below
      plan.md                 what the harness intended to do
      setup.log pretest.log driver.log oracle.log
      grade.md                PASS/FAIL plus the evidence block
      work/                   the task's working copy (gitignored)
```

### `metrics.json` schema

`schema: aidd-bench-metrics/1`. Units are stated in the field name or here; unknown values
are JSON `null`, which the report renders as `not measured`.

| Field | Type | Meaning |
| --- | --- | --- |
| `schema` | string | Always `aidd-bench-metrics/1` |
| `run_id` | string | The run-id |
| `task_id` | string | Task `id` |
| `rep` | int | 1-based repetition index |
| `driver` | string | `aidd`, `baseline`, or `external:<cmd>` |
| `defect_id` | string or null | Set when the rep ran with an injected defect |
| `started_at` | string or null | ISO-8601 UTC, e.g. `2026-08-06T10:15:00Z` |
| `finished_at` | string or null | ISO-8601 UTC |
| `wall_clock_seconds` | number or null | Seconds, driver invocation only |
| `tokens_input` | int or null | Prompt tokens, from the runtime's usage output |
| `tokens_output` | int or null | Completion tokens, same source |
| `tokens_total` | int or null | Sum. Never derived from a guess |
| `usage_source` | string | `runtime-usage` or `not-measured` |
| `cost_usd` | number or null | Only when the runtime reports a price. Never inferred |
| `setup_status` | enum | `ok` / `fail` / `not-run` |
| `pretest_status` | enum | `unsatisfied-as-required` / `already-satisfied` / `error` / `not-run` |
| `grade` | enum | `PASS` / `FAIL` / `not measured` |
| `defect_caught_by` | string or null | The `visible_to` token that actually fired |
| `notes` | string | Free text, e.g. why usage was unavailable |

### How tokens and time are recorded

- **Wall-clock** is measured by the harness around the driver invocation only — setup,
  pretest, and grading are excluded, because they are harness cost, not arm cost.
- **Tokens come from the runtime's own usage output.** The harness does not tokenize
  anything and does not estimate. A driver reports usage by writing a single JSON object to
  the path in `BENCH_USAGE_FILE` before it exits:

  ```json
  {"tokens_input": 1234, "tokens_output": 567, "cost_usd": null}
  ```

  For AIDD's own arm that number is whatever the agent CLI reports for the session (on
  Claude Code, the session usage summary). If the file is absent or unparseable,
  `usage_source` is `not-measured`, the token fields stay `null`, and the report prints
  `not measured`. A missing measurement is never rendered as a zero and never estimated.
- **Cost per caught defect** is therefore `not measured` unless both a token count and a
  defect outcome exist for the same run.

### Environment capture

`env.md` is written at run start and holds: UTC timestamp, `uname -a`, `git rev-parse HEAD`
of this framework repo plus whether the tree was dirty, `bash --version`,
`python3 --version`, `git --version`, the driver command string, the corpus tag, the
requested rep count, and every `BENCH_*` variable that was set with its value redacted if
the name matches `*KEY*|*TOKEN*|*SECRET*`. A run whose framework tree was dirty is marked
as such — a dirty tree disqualifies the run from a published claim.

## Repetitions and variance

LLM runs are **stochastic**. The same task, the same intent, and the same arm can pass on
one rep and fail on the next, and token counts vary by tens of percent. A single rep is an
anecdote.

- Any published claim requires **≥3 reps per task per arm**. The scripts default to 1 rep
  for cheap mechanical exercise, and `bench-report.sh` marks any task with fewer than 3
  reps `UNDER-REPPED` in the report.
- Report **median and range** (min–max), never a mean alone, for wall-clock and tokens.
- Report pass rate as `k/n reps`, not as a percentage of one attempt.
- Do not discard a rep. A rep that crashed is a rep that crashed, and it is reported.

## Comparison procedure

For a comparative claim, run all arms over the **same task list**, in the same window, on
the same machine:

1. Freeze the corpus. Commit it. Record the framework `HEAD` in `env.md`.
2. Write the graders first (they are already in the task files) and do not touch them again
   for the duration of the run.
3. For each arm, for each task, for each rep 1..N: fresh work dir, `setup`, `pretest`
   (must fail), then the driver receives the task's `intent` **verbatim** and nothing else.
4. Grade every rep with the same `oracle`, by `bench-grade.sh`, from the recorded run dir.
5. Aggregate per arm with `bench-report.sh`, then compare arms only on tasks where **all**
   arms produced at least the required reps. A task any arm could not attempt is reported
   separately, not dropped.

Arms:

- `--driver baseline` — the mandatory control. A single agent, one pass, no Layer-1 review
  fan-out, no Layer-2 adjudication, no Layer-3 supervision. Configured by
  `BENCH_BASELINE_CMD`. Without a baseline arm there is no comparative claim to make,
  only an absolute one (ADR 014).
- `--driver aidd` — the framework under test. Configured by `BENCH_AIDD_CMD`.
- `--driver external:<cmd>` — any other harness (AI-DLC, Superpowers, a bare agent CLI).
  The harness treats it as opaque: same intent in, same oracle out, same metrics contract.

The harness ships **no LLM and no API key**. Every arm is a command the runner supplies.
That is deliberate: it keeps the comparison honest and keeps `--dry-run` runnable in CI.

## Defect runs

A defect run is a normal rep with one extra step between `setup` and the driver:
`bench-inject.sh --defect <id> --apply`. Then:

1. The arm runs against the injected tree with the task's unmodified `intent`.
2. The defect's `grader` decides **caught** or **escaped**, and — when caught — which
   `visible_to` layer's artifact actually surfaced it.
3. `bench-report.sh` reports caught/escaped **by layer**, so a defect the baseline arm
   catches with a plain test run is not credited to Layer 2.

### Defect grader contract

A defect's `grader` is a `bash -euo pipefail` script run with CWD = the rep directory, so it
can read:

| Path | Contents |
| --- | --- |
| `./work/` | The working copy the arm changed |
| `./work/.aidd/changes/` | The AIDD arm's own artifact tree, when the arm is AIDD |
| `./driver.log` | Everything the driver wrote to stdout and stderr |
| `./setup.log` `./pretest.log` `./oracle.log` | The harness's own phase logs |

Exit codes: **0 = caught**, **1 = escaped**, **≥2 = grader error** (never silently a catch).
A grader that exits 0 prints, as its last line, the layer token that actually fired:

```text
CAUGHT-BY: L2-tally
```

`bench-report.sh` reads that token into `defect_caught_by`, which is how caught-versus-missed
is sliced **by layer**. Two rules keep the slicing honest:

1. **A catch requires a report, not a symptom.** A defect that merely makes the task's oracle
   fail is an *escape* accompanied by a failed task. Detection means an artifact or transcript
   in which the arm said what was wrong.
2. **Credit goes to the layer that fired, not the layer that was supposed to.** If the
   baseline arm catches a `mocked-proof` defect from its own test run, the report records
   `L1-tests` for that arm. `visible_to` is the hypothesis; `defect_caught_by` is the
   measurement, and they are allowed to disagree — that disagreement is a result.

`injection_mode: command` defects are applied and reverted mechanically by
`bench-inject.sh` (git-based; it refuses to run on a dirty tree, and `--revert` restores
via `git checkout`/`git clean` of the paths it touched). `injection_mode: instruction`
defects cannot be applied by a script — they describe a behavior the arm must be asked to
produce, such as proving an AC with a mock. `bench-inject.sh` prints those verbatim and
exits 2 rather than pretending to have applied anything.

## Anti-cheating rules

These are the rules that make a number worth reading. Breaking any of them invalidates the
run, and the report has a section that says whether each was upheld.

1. **No task-specific prompts.** An arm receives the task's `intent` and whatever standing
   configuration it always has. No hints, no "remember to check X", no per-task system
   prompt.
2. **Identical intents across arms.** Byte-identical. The harness passes the same `intent`
   string to every driver.
3. **Graders written before runs.** The `oracle` and the defect `grader` are committed
   before the first rep. A grader edited after seeing a result is a new grader, which
   invalidates every earlier rep it now judges.
4. **No retry-until-pass.** N reps are decided up front. You may not run a 4th rep because
   the first three were unflattering, and you may not drop a rep for being an outlier.
5. **Publish failures.** Every attempted task appears in the report, including
   `SETUP-FAIL`, `PRETEST-ALREADY-SATISFIED`, crashes, and timeouts.
6. **No corpus tuning between arms.** The task list is frozen before the first arm runs.
7. **Baseline is mandatory for any comparative claim.** "AIDD caught N defects" without an
   arm that had no verification layers is not a comparison.
8. **Report the harness's own cost.** The verification layers cost tokens. Cost overhead vs
   the baseline arm is a headline number, not a footnote.

## Derived metrics

All of these are `not measured` unless every input exists in a recorded `metrics.json`:

| Metric | Definition |
| --- | --- |
| pass rate | reps graded `PASS` / reps attempted, per task per arm |
| defect-detection rate | defects caught / defects injected, per arm and per layer |
| escape rate | 1 − defect-detection rate, same slicing |
| cost per caught defect | total `tokens_total` over defect reps / defects caught |
| cost overhead vs baseline | arm median `tokens_total` / baseline median `tokens_total` |
| wall-clock overhead | arm median `wall_clock_seconds` / baseline median |

## Evidence format

Every grade and every script that claims an outcome emits an evidence block in the
mandatory format from `core/protocol/evidence.md`:

```text
$ <command>
<trimmed output>
[exit <code>] <ISO-8601 timestamp>
```

`bench-grade.sh` writes exactly that into `grade.md`, and `bench-report.sh` quotes it. A
grade with no evidence block is not a grade.

## Suite

The bench suite runs as part of the repository's test runner:

```bash
bash tests/bench.test.sh     # or: bash tests/run.sh
```

It asserts the schemas, the corpus floors (≥24 tasks, ≥4 per class, ≥6 offline), full
`defect_class` coverage, the presence of the three Layer-2-justifying classes, that every
defect `target` resolves, that `bench-run.sh --dry-run --offline` exits 0 and lists every
offline task, and that the results template carries the `not measured` convention. It runs
offline, in seconds, with no API key.
