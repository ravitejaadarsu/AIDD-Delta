# AIDD Delta

**A multi-agent engineering pipeline that carries one intent — a feature request, a Jira
ticket, a bug report — from clarified requirements to a merge-ready pull request, gating
every step on executed evidence rather than on an agent's say-so.** It is for engineers who
would rather spend agent budget on adversarial verification up front than spend their own
afternoon discovering, in review, that a green test proved nothing.

## Status: honest

| | |
|---|---|
| **Version** | v0.4.0 — pre-1.0, under active development, breaking changes expected |
| **Authorship** | single author; no external contributors yet |
| **External validation** | **none yet.** No third-party team has run this end to end and reported back. If you do, [we publish it](docs/case-studies/README.md) — including negative results |
| **CI** | green on `main` ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) — self-tests plus pinned ShellCheck and markdownlint, with a linter-drift check so local and CI lint byte-identically |
| **Self-tests** | `bash tests/run.sh` — zero-dependency bash + python3 stdlib; 17 suites at the time of writing. The runner prints `suites=N failures=N`; CI fails on any non-zero |
| **Benchmarks** | **no published benchmark results yet.** The harness ships in [`bench/`](bench/harness.md) with its task set, defect corpus, and comparison arms — run it yourself and report what you get |
| **Runtime tiers** | Tier 1 Claude Code · Tier 2 Codex CLI · Tier 3 any other agent CLI or plain LLM ([capability matrix](docs/capability-matrix.md)) |

**What this framework does and does not promise.** It *gates* delivery on executed evidence
and adversarial verification: a claim without a command, an exit code, and output is
rejected; a review finding that cannot survive a motivated skeptic does not block; an
acceptance criterion without executed proof blocks like a failing test. That is a process
guarantee about what is allowed to ship, not a guarantee about outcomes. It does not promise
defect-free code, green CI on your repo, or that the pipeline will not be wrong about
something — it promises that being wrong has to get past named, recorded checks first.

## How to read the claims on this page

Every claim below is one of three kinds, and says which:

- **[designed]** — specified in the protocol or an ADR, and enforced by the playbooks. The
  link is the specification; read it and judge for yourself.
- **[measured]** — backed by a run whose artifacts you can inspect. Today that means the
  self-test suite and CI. Pipeline-quality numbers become measured only when
  [`bench/`](bench/harness.md) results are published — none are yet.
- **[planned]** — on the [roadmap](ROADMAP.md), not built.

## What it does

Badges: **[all tiers]** works identically on Tier 1/2/3 · **[Tier 1]** Claude Code only
(see the [capability matrix](docs/capability-matrix.md) for the degradation path).

- **Requirements before generation.** **[designed]** **[all tiers]** Clarifying questions
  are asked (or, in `take-care`, self-answered with logged confidence) before any artifact
  is generated; the PRD carries testable acceptance criteria with stable ids that thread
  through stories, tests, and the final AC matrix.
  → `core/playbooks/20-inception.md`
- **Judged architecture, then a devil's advocate.** **[designed]** **[all tiers]** Three
  candidate designs from different lenses, scored by independent judges against a fixed
  rubric, plus an Independent Thinker writing the strongest honest case *against* the winner.
  → `core/roles/arch-judge.md`, `core/roles/independent-thinker.md`
- **Test-first implementation with recorded failing-test evidence.** **[designed]**
  **[all tiers]** A Builder must show the test failing before the implementation lands;
  stories own disjoint file sets, checked mechanically.
  → `core/roles/builder.md`, `core/protocol/evidence.md`
- **Adversarial verification of every finding.** **[designed]** **[all tiers]** Each review
  finding is handed to a verifier whose job is to *refute* it. Only confirmed defects block,
  so the review funnel does not drown delivery in noise.
  → [ADR 004](docs/design/decisions/004-adversarial-verification.md)
- **Three-layer verification.** **[designed]** **[all tiers]** Workers build and test;
  a Master Agent, an Auditor, and Tally interrogate per-AC proof and reconcile every tracked
  work item; the Supervisor adjudicates what survives. Budgets are hard — exhaustion blocks
  or escalates, never loops.
  → [three-layer verification](docs/three-layer-verification.md),
  [ADR 006](docs/design/decisions/006-three-layer-verification.md)
- **A supervisor over the supervisors.** **[designed]** **[all tiers]** An independent
  auditor inspects every agent hand-off at each phase boundary and can block phase advance;
  the process is held to account, not just the code.
  → `core/protocol/supervision.md`
- **Staged, gated, resumable.** **[designed]** **[all tiers]** Discrete evidence-gated
  phases with human checkpoints at G1/G2/G3 — or full autonomy with an identical audit
  trail. State is schema-validated; approvals bind to artifact hashes and go stale when the
  artifact changes.
  → `core/protocol/gates.md`, `core/protocol/state-protocol.md`
- **Shared context instead of repeated crawling.** **[designed]** **[all tiers]** A
  gitignored snapshot pack is rebuilt at every phase boundary and Construction wave; roles
  read it first, and a missing pack degrades context explicitly rather than silently.
  → [context snapshots](docs/context-snapshots.md),
  [ADR 007](docs/design/decisions/007-context-snapshots.md)
- **Query the repo instead of reading it.** **[built]** **[all tiers]** A dual-state index
  records every symbol's span plus the git blob hash of the bytes it was parsed from, so a
  role pulls one function instead of the file containing it, and a rebuild reparses only
  what moved. Tree-sitter is used when importable and never required; a file no parser
  understands still gets a path-and-hash entry. A span is re-verified against live bytes
  before it is served, so a stale span is never handed to a reader.
  → [context index](docs/context-index.md),
  [ADR 020](docs/design/decisions/020-execution-environment.md)
- **Sandboxed test execution, model routing, and self-triggering.** **[built]**
  **[all tiers]** Agent-issued test commands run in a disposable container (network off,
  repo read-only, never root); dispatch classes route to different models with per-model
  rates feeding the cost ledger; a pre-commit hook and a PR workflow trigger the framework
  without anyone remembering to. Every degradation is announced — a silent fallback that
  leaves a caller believing it was isolated is the one unacceptable outcome.
  → [execution environment](docs/execution-environment.md),
  [ADR 020](docs/design/decisions/020-execution-environment.md)
- **Parallel subagent dispatch.** **[designed]** **[Tier 1]** Fan-outs run concurrently,
  each subagent with its own context window. Tiers 2 and 3 run the same fan-out
  sequentially — same artifacts, proportionally more wall clock.
  → `core/protocol/dispatch.md`
- **Hook-enforced protocol invariants.** **[designed]** **[Tier 1]** Five hooks make four
  invariants mechanical: scope guard, state schema validation, pending-gate check on stop,
  dispatch audit logging (plus snapshot refresh). Off Tier 1 these are orchestrator duties
  that the Supervisor *detects* lapses in rather than prevents.
  → `hooks/hooks.json`, [capability matrix](docs/capability-matrix.md)
- **Portable core.** **[designed]** **[all tiers]** All logic is plain markdown in `core/`,
  vendored into your repo at `.aidd/framework/`. The plugin layer only points at it.
  → [portability](docs/portability.md),
  [ADR 001](docs/design/decisions/001-portable-core.md)
- **Optional integrations that degrade out loud.** **[designed]** Playwright live re-proof
  of disputed UI results and Jira ticket pull are used where available and recorded as
  degraded — with the taken path named — where not.
  → `core/protocol/jira-sync.md`, `core/protocol/test-debate.md`

## Cost versus rigor

Exhaustive verification on a copy change is waste; skipping it on an auth change is
negligence. So rigor is a **mode**, chosen per change: **[designed]** **[all tiers]**

- a copy or config tweak runs the cheap path — fewer dispatches, fewer adjudication rounds;
- a normal feature runs the standard path;
- an auth, payments, migration, or public-API change runs the exhaustive path.

What each mode turns on and off, and what it costs in dispatches, is specified in
[docs/rigor-modes.md](docs/rigor-modes.md) (protocol: `core/protocol/rigor-modes.md`). Token
cost per mode is not yet measured — it is one of the numbers [`bench/`](bench/harness.md) is
built to produce.

## Why three layers

The bet behind the whole design is a **hypothesis, not a finding**: ordinary AI code review
reliably misses a specific family of defects, and layered adversarial verification catches
them. The family is roughly —

- assertions that pass without exercising the code path they claim to prove (mocked
  dependency, tautological assertion);
- acceptance criteria that are *asserted* done with no executed evidence anywhere;
- work items silently dropped between the PRD, the stories, and the diff;
- regressions visible only against a pre-change baseline, not in the diff itself;
- happy-path-only coverage where the boundary and abuse cases are the risk.

Each of those is a defect class in the harness's defect catalogue (`bench/defects/`, method:
[`bench/harness.md`](bench/harness.md)), which exists to test whether the three layers
actually catch them at a cost worth paying —
see [docs/benchmarks.md](docs/benchmarks.md). **No published benchmark results yet.** Until
there are, treat the three-layer design as a well-specified hypothesis:
[three-layer verification](docs/three-layer-verification.md) tells you exactly what it does,
so you can disagree with it precisely.

## Compared to adjacent approaches

Neither of these is a competitor to beat; they are different shapes of the same ambition,
and the differences are worth knowing before you pick one.

- **AI-DLC** (AWS's AI-Driven Development Lifecycle) — a methodology for restructuring the
  software lifecycle around AI with human checkpoints at each phase. AIDD Delta shares the
  staged, human-gated shape; it differs by shipping the lifecycle as executable playbooks
  with a machine-checked state protocol and an adversarial verification layer, rather than as
  guidance a team adapts.
- **Superpowers** — a broad library of composable Claude Code skills, invoked as needed.
  AIDD Delta is not a library: it is one opinionated end-to-end pipeline with a fixed phase
  order and gates. The two are complementary — skills you reach for, versus a pipeline that
  dispatches roles at you.

Both are defined as comparison arms in the harness so the difference can be measured instead
of argued. **No results are published yet** ([docs/benchmarks.md](docs/benchmarks.md)).

## Quickstart

- **Tier 1 — Claude Code:** [docs/quickstart-claude.md](docs/quickstart-claude.md)
- **Tier 2/3 — Codex CLI or any agent CLI:**
  [docs/quickstart-codex.md](docs/quickstart-codex.md)
- **First run against a bundled fixture, offline, ~15 minutes:**
  [docs/adoption.md](docs/adoption.md)

## Layout

| Path | Purpose |
|---|---|
| `core/` | The portable framework: playbooks, roles, protocol, templates, schemas |
| `commands/`, `agents/`, `skills/`, `hooks/` | Claude Code plugin shell — pointers only |
| `install.sh` | Universal installer — vendors `core/` into a target repo's `.aidd/` |
| `tests/` | Framework self-tests (zero-dependency bash + python3) |
| `bench/` | Benchmark harness: task set, seeded defect corpus, comparison arms |
| `docs/` | Human-oriented reference, ADRs, case studies |

## Contributing

The project needs external runs more than it needs features. Bug reports, case studies
(negative ones included), and bench task contributions are the highest-value input:
[CONTRIBUTING.md](CONTRIBUTING.md) · [docs/adoption.md](docs/adoption.md) ·
[ROADMAP.md](ROADMAP.md).

## License

MIT — see [LICENSE](LICENSE).
