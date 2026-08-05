# Adoption — your first fifteen minutes

The fastest honest way to judge AIDD Delta is to run it once against a tiny bundled fixture,
offline, and read the artifacts it produces. That takes about fifteen minutes and touches
none of your own code.

Prerequisites: `bash`, `python3`, `git`. Nothing else. No network calls are required for the
fixture run.

## 1. Prove the framework itself is sound (2 minutes)

```bash
git clone https://github.com/ravitejaadarsu/AIDD-Delta.git ~/AIDD-Delta
cd ~/AIDD-Delta
bash tests/run.sh
```

Expect a final line of the form `suites=N failures=0`. ShellCheck and markdownlint run only
if installed; the runner says which it skipped. If `failures` is not zero on a clean
checkout, that is a bug worth an issue —
[`.github/ISSUE_TEMPLATE/bug_report.md`](../.github/ISSUE_TEMPLATE/bug_report.md).

## 2. Set up the fixture repo (3 minutes)

The bundled fixture is a five-function Python todo module with unittest tests — small enough
that you can read every artifact the pipeline produces and check it against reality.

```bash
cp -R ~/AIDD-Delta/tests/fixtures/sample-project /tmp/aidd-first-run
cd /tmp/aidd-first-run
git init && git add -A && git commit -m "baseline"
python3 tests/test_todo.py     # confirm the baseline is green
```

## 3. Install AIDD into it (2 minutes)

```bash
~/AIDD-Delta/install.sh
```

This vendors `core/` into `.aidd/framework/`, patches `AGENTS.md` with the routing table, and
seeds state. It never touches a constitution, memory, learnings, or existing changes.

## 4. Run the pipeline on one small intent (8 minutes of agent time)

Use this intent verbatim — it is the canned dogfood scenario
(`tests/scenarios/todo-api.md`), so you have an expected-artifact checklist to grade against:

```text
Add a complete(items, index) operation to the todo module: marks the item done, renders
done items with a "[x] " prefix, rejects out-of-range indexes.
```

- **Tier 1 (Claude Code):** `/aidd:mode let-me-look` then `/aidd:go "<intent>"`.
- **Tier 2 (Codex CLI):** `AIDD: build <intent>`.
- **Tier 3 (any other CLI or a plain LLM):** paste `.aidd/framework/prompts/go.md` followed
  by the intent.

Stay in `let-me-look` for a first run. The point of the exercise is to read the G1 and G2
gate digests and decide whether you agree with them.

## 5. Grade it

Walk `.aidd/changes/<id>/` against the checklist in `tests/scenarios/todo-api.md`. The
questions worth asking:

- Does `prd.md` carry acceptance criteria you would actually accept, with stable ids?
- In each story's Builder Report, does the failing-test evidence **precede** the
  implementation evidence, with real commands and exit codes?
- In `ac-matrix.md`, is every AC backed by an executed test, or is any of them asserted?
- Does `supervision/audit.log` account for every dispatch, and do the phase reports say
  COMPLIANT for the right reasons?
- Where a tool was missing, is the degradation **recorded with a reason** rather than
  silently skipped?

Anything that fails those questions is a framework defect, not your mistake. Report it.

## What to expect on your tier

| | Tier 1 — Claude Code | Tier 2 — Codex CLI | Tier 3 — other CLI / plain LLM |
|---|---|---|---|
| Fan-outs | Concurrent subagents | Sequential, documented order | Sequential, each dispatch pasted |
| Wall clock on the fixture | Shortest | Longer, roughly with fan-out width | Longest; operator-paced |
| Protocol enforcement | Hooks prevent four violation classes | Orchestrator duties; Supervisor detects lapses | Same as Tier 2 |
| Operator surface | `/aidd:*` commands | `AIDD: …` natural language | Pasted prompts from `.aidd/framework/prompts/` |
| Artifacts produced | Identical | Identical | Identical |
| Gate strength | Identical | Identical | Identical |

Full cell-by-cell detail and the degradation contract:
[capability-matrix.md](capability-matrix.md).

## The three failure modes people actually hit

**1. "It just stopped and nothing is happening."** Almost always a pending gate. In
`let-me-look`, G1/G2/G3 set `phase_status: awaiting_gate` and wait for you. On Tier 1 the
stop hook tells you; on Tiers 2 and 3 there is no hook, so nothing reminds you.
*Fix:* run the status prompt (`/aidd:status`, `AIDD: status`, or
`.aidd/framework/prompts/status.md`), then approve or revise. Nothing is lost — the gate
lives in `state.yaml`.

**2. "A state write failed schema validation" (or state drifted and resume refuses).** The
state files are schema-validated on purpose; an out-of-enum phase or a missing required key
stops the run rather than corrupting the ledger.
*Fix:* `python3 .aidd/framework/scripts/aidd-validate.py
.aidd/framework/schemas/change-state.schema.json .aidd/changes/<id>/state.yaml`, read the
error, and fix the named field per `core/protocol/state-protocol.md`. Do not delete keys to
make the validator quiet — the schema is the contract. On Tiers 2 and 3, run that validator
after every state write; Tier 1's hook does it for you.

**3. "A quality gate came back `na`, or a role reported degradation."** Expected, by design,
when an optional tool is absent: no mutation tool means `mutation_floor_met: na` with a
reason; no Playwright and no Node means a UI re-proof degrades to a CLI transcript; a missing
snapshot pack degrades a role's context, not its correctness.
*Fix:* nothing, if the recorded reason is accurate — that is the evidence protocol working
(`core/protocol/evidence.md`). Install the optional tool if you want the stronger check. What
is *not* acceptable is a gate that passed with no reason recorded; that is a defect worth an
issue.

## How to report results back

Both of these are wanted, and negative results are published just like positive ones.

- **Something broke, or an artifact was wrong:** open a bug report
  ([`.github/ISSUE_TEMPLATE/bug_report.md`](../.github/ISSUE_TEMPLATE/bug_report.md)). It
  asks for your tier, runtime, rigor mode, and the paths to the run's artifacts — without
  those a report usually cannot be acted on.
- **You ran it on a real repo:** submit a case study
  ([`.github/ISSUE_TEMPLATE/case_study.md`](../.github/ISSUE_TEMPLATE/case_study.md),
  format: [case-studies/TEMPLATE.md](case-studies/TEMPLATE.md)). This is the single most
  useful contribution the project can receive right now — there is no external validation
  yet, and one honest write-up of a real run is worth more than a feature.
- **You ran the benchmark harness:** results plus the run's artifacts, per
  [benchmarks.md](benchmarks.md). No results are published yet; yours could be the first.

Reading next: [CONTRIBUTING.md](../CONTRIBUTING.md) for the dev loop,
[case-studies/README.md](case-studies/README.md) for what a publishable case study must
carry.
