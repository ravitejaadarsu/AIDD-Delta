# Contributing to AIDD Delta

The project is pre-1.0, single-author, and has **no external validation yet**. That means the
highest-value contribution is not a feature — it is a run. A bug report from a real repo, an
honest case study (negative ones very much included), or a benchmark result with artifacts
moves this project further than new capability does. Start at
[docs/adoption.md](docs/adoption.md) if that is what you came for.

If you are here to change the framework, read on.

## The one rule that matters

**`core/` is the single source of truth.** All phase logic, gate semantics, and state
protocol live in the portable markdown under `core/`. The Claude Code plugin layer
(`commands/`, `agents/`, `skills/`, `hooks/`) must only *reference* the vendored core —
never restate it. If the same rule appears in two files, that is a bug: fix it by
deleting the copy outside `core/`.

## Repo layout

| Path | What it is | Rule |
|---|---|---|
| `core/playbooks/` | The executable phase contracts — `00-pipeline.md` is canonical | A step that exists only in a protocol or role file is unreachable; the playbook must wire it (`tests/playbooks.test.sh` enforces this) |
| `core/protocol/` | Cross-phase rules: gates, state, evidence, supervision, dispatch, rigor modes | Rules, not steps. Referenced by playbooks |
| `core/roles/` | One file per specialist role, with its protocol and report format | Each has a matching `agents/aidd-<role>.md` wrapper on Tier 1 |
| `core/templates/`, `core/schemas/` | Artifact templates and the JSON Schemas that validate state | Change a template or schema → update `tests/fixtures/` |
| `core/prompts/` | Tier 3 entry points: paste-able phase prompts | |
| `commands/`, `agents/`, `skills/`, `hooks/` | Claude Code plugin shell | **Pointers only.** Each wrapper points at its vendored copy under `.aidd/framework/`; `tests/manifest.test.sh` fails if a wrapper stops pointing at a real role file |
| `install.sh` | Vendors `core/` into a target repo's `.aidd/framework/` | Idempotent; never touches user artifacts |
| `tests/` | Zero-dependency self-tests (bash + python3 stdlib) | |
| `bench/` | Benchmark harness: task set, seeded defect corpus, comparison arms | |
| `docs/` | Human-oriented reference, ADRs, case studies | Mirrors `core/`; never the source of truth for a rule |

The plugin layer duplicating core logic is the failure mode this layout exists to prevent —
it is why [ADR 001](docs/design/decisions/001-portable-core.md) exists and why reviewers look
for it first.

## The local dev loop

```bash
bash tests/run.sh          # the whole suite; must end in failures=0
bash scripts/check-refs.sh # every path referenced in markdown must exist
```

`tests/run.sh` needs only bash and python3. The two linters are **pinned** so local and CI
lint byte-identically — CI asserts there is no version drift, and an unpinned linter once
broke CI for three releases, so never unpin one:

- **markdownlint**: the version is pinned in `tests/run.sh` (`MDLINT_VERSION`). If
  `markdownlint-cli2` is not on your PATH the runner falls back to
  `npx -y markdownlint-cli2@<pinned>`, so having Node is enough. Policy lives in
  `.markdownlint.jsonc`. Practical rules that catch most contributors: fenced blocks need a
  language, lists and tables need blank lines around them, table columns must be consistent.
- **ShellCheck**: install it (`brew install shellcheck`, `apt-get install shellcheck`).
  Locally the runner skips it when absent and says so; CI runs with `AIDD_STRICT_LINT=1`,
  which turns a missing linter into a failure. Run the suite with that flag yourself before
  opening a PR if you touched shell.

Run both commands before every commit, not just before the PR. `check-refs.sh` in particular
fails the moment you add or rename a file whose references are inconsistent — fix all
references rather than removing the link.

## Making a change

1. Edit the relevant file under `core/` (playbook, role, protocol, template, or schema).
2. If you changed a YAML template or schema, update fixtures in `tests/fixtures/`.
3. Add or extend a test that would have failed before your change.
4. Update the mirror page under `docs/` if you changed behavior a user can observe.
5. Run the dev loop above. Version bumps go through `scripts/bump-version.sh` (single
   source: `VERSION`).

## Every new capability needs three things

A capability is anything a user can observe or depend on: a new role, a new gate, a new hook,
a new protocol duty, a new command, a new integration. Adding one requires **a tier row, a
test, and a docs page** — all three, in the same PR:

1. **A tier row** in [docs/capability-matrix.md](docs/capability-matrix.md), with a filled
   cell for **every** tier — supported, or degraded with the alternative mechanism named, or
   unsupported. A capability that cannot state its degradation path on Tiers 2 and 3 is not
   ready to ship ([ADR 015](docs/design/decisions/015-capability-tiers.md)).
   `tests/claims.test.sh` fails on an empty cell.
2. **A test** under `tests/` that fails without the change. Grep-level conformance assertions
   are fine and are the house style — see `tests/playbooks.test.sh`.
3. **A docs page** (or a section in the right existing page) that names the capability's
   tier. A capability claim without a tier is a defect.

## Design decisions need an ADR

Significant decisions are recorded as ADRs in `docs/design/decisions/`, numbered
sequentially. Add one when you change an architectural rule — state protocol, gate semantics,
installer behavior, verification topology, tier definitions, or the blocking economy (what is
allowed to stop delivery).

The house format is three labelled paragraphs and nothing else:

- **Decision.** What is now true, specifically enough to implement from.
- **Why.** The forces, including the option you rejected and what it would have cost.
- **Consequence.** What this obliges every future change to do, what it costs, and how it
  degrades. Name the trade-off you accepted; an ADR with no cost section is unfinished.

Read [ADR 009](docs/design/decisions/009-continuous-test-debate.md) for a worked example of
the depth expected. Amending an earlier ADR is normal — say which one you are refining and
whether you overturn it (see [ADR 015](docs/design/decisions/015-capability-tiers.md)
refining ADR 001).

## Adding a benchmark task or a seeded defect

The harness under `bench/` is where comparative claims come from, and it is the part of the
repo most in need of contributions. Read `bench/harness.md` first — it defines the task
schema, the comparison arms, and the scoring rules; this section only says where things go.

- **A benchmark task** describes a repo fixture, an intent, and the objective pass criteria a
  run is scored against. Add one when you can state a task class the current set does not
  cover (a migration, a concurrency bug, a public-API break).
- **A seeded defect** goes in `bench/defects/` and is the more valuable of the two: a defect
  is only worth seeding if you can argue that ordinary review would plausibly miss it, and
  say which verification layer you expect to catch it. State that expectation in the defect
  file — a defect nobody predicted the outcome for cannot confirm or refute anything.

Contribute the fixture and the expectation, never a result without its artifacts. Benchmark
numbers are published only with the run that produced them
([docs/benchmarks.md](docs/benchmarks.md)).

## Pull requests

The PR template's checklist is the actual bar: suite green, capability-matrix row for any new
capability, an ADR for a design change, and docs updated. A PR that leaves those unchecked
without saying why does not get reviewed. Issue templates ask for your tier, runtime, rigor
mode, and artifact paths for the same reason the framework does — a claim without evidence
cannot be acted on.
