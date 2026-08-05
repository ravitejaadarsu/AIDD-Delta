# Case Study Template

Copy this file, fill every field, and submit it via
[`../../.github/ISSUE_TEMPLATE/case_study.md`](../../.github/ISSUE_TEMPLATE/case_study.md).
Every heading below is **required**. Write `unknown` or `not measured` where you genuinely
do not have a number — that is honest and publishable. Leaving a section blank, or deleting
it, is not: the submission comes back instead of going up.

Redact secrets, customer data, and proprietary source before submitting. Say what you
redacted.

---

## Summary

One paragraph: what you asked for, what you got, and whether it was worth it. Lead with the
verdict, including a negative one.

## Context

- **Repo class**: language(s), approximate size (LOC or files), age, test maturity
  (none / thin / good), brownfield or greenfield, monorepo or single service.
- **Task class**: bug fix · feature · refactor · migration · auth/payments/security ·
  public-API change · other (say which).
- **Rigor mode**: which mode the change ran in, and whether you overrode the default.
- **Runtime and tier**: Claude Code (Tier 1) · Codex CLI (Tier 2) · other agent CLI or plain
  LLM (Tier 3). Name the models used.
- **Autonomy mode**: `let-me-look` or `take-care`, and any mid-run switch.
- **AIDD Delta version**: from `VERSION` or the plugin manifest.

## Cost

- **Run duration**: total wall clock. Per-phase breakdown if you have it.
- **Token cost**: total tokens (or currency, with the model mix named). Per-phase breakdown
  if your runtime reports it. `not measured` is acceptable; omitting the heading is not.
- **Human time**: how long *you* spent — gate reviews, corrections, hand-holding.

## Defects caught by layer

One row per defect the pipeline caught, attributed to the layer that caught it. This is the
table the project's central hypothesis stands or falls on, so be precise about which layer
first surfaced each item.

| # | Layer (1 workers / 2 adjudicators / 3 supervisor) | Which role | What the defect was | Would ordinary review have caught it? |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |

If a layer caught nothing, say so explicitly — `Layer 2: nothing` is a real and useful
result.

## Defects the framework missed

Anything that got through the pipeline and was found later — in human review, in CI, in
staging, in production. Include how it was found. If nothing was missed *so far*, say how
long the change has been live, because "nothing yet, three days" and "nothing yet, four
months" are different claims.

## What shipped

- Merged, or not? If not, where it stopped and why.
- What you changed by hand after the PR, and why.
- Did CI pass on the first push?

## What the framework got wrong

Required. Bad or noisy findings, wasted fix loops, misjudged architecture, gate digests that
hid something important, degradations that should have blocked, friction that made you want
to stop using it. A study with nothing here is treated as incomplete.

## What you would tell the next team

Two or three sentences of advice, including "don't use it for X".

## Artifact links

Verifiability. A submission without these is not published.

- **PR link** (or a redacted diff summary if the repo is private).
- **Run artifact directory**: the `.aidd/changes/<id>/` tree, or a redacted archive of it.
  At minimum: `prd.md`, `epic.md`, the Builder Reports, `qa/verdicts.md`,
  `qa/test-report.md`, `ac-matrix.md`, `supervision/`, and the gates ledger from
  `state.yaml`.
- **Benchmark results**, if you also ran the harness.
- **CI run link**, if public.

## Attribution

How you want to be credited — name, handle, org, or anonymous. Anonymous is fine and does
not weaken the submission.
