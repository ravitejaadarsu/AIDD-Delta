---
name: Case study submission
about: Report a real AIDD Delta run on a real repo — negative results welcome
title: "case study: "
labels: case-study
---

<!-- This is the most valuable thing you can send this project. There is no external
validation yet; one honest write-up of one real run is worth more than a feature.

Two rules (docs/case-studies/README.md):
  1. Unverifiable submissions are not published — the artifact links and per-layer defect
     counts have to be there and have to add up.
  2. Negative results ARE published, with the same prominence and the same credit. "It cost
     more than it was worth on this class of change" is a finding, not a complaint.

Fill the sections below, or paste a completed copy of docs/case-studies/TEMPLATE.md, which
has the same fields with the reasoning for each. Write "not measured" where you have no
number — honest gaps are publishable; missing sections are not. Redact secrets, customer
data, and proprietary source, and say what you redacted. -->

## Summary

One paragraph: what you asked for, what you got, whether it was worth it. Lead with the
verdict.

## Context

- **Repo class**: language(s), approximate size, age, test maturity, brownfield/greenfield
- **Task class**: bug fix · feature · refactor · migration · auth/payments/security ·
  public-API change · other
- **Rigor mode**:
- **Runtime and tier**: Tier 1 Claude Code · Tier 2 Codex CLI · Tier 3 other / plain LLM;
  models used
- **Autonomy mode**: `let-me-look` · `take-care`
- **AIDD Delta version**:

## Cost

- **Run duration** (wall clock, per phase if known):
- **Token cost** (total, per phase if your runtime reports it; `not measured` is acceptable):
- **Human time** (gate reviews, corrections, hand-holding):

## Defects caught by layer

| # | Layer (1 / 2 / 3) | Which role | What the defect was | Would ordinary review have caught it? |
|---|---|---|---|---|
| 1 | | | | |

If a layer caught nothing, say so — `Layer 2: nothing` is a real result.

## Defects the framework missed

What got through and was found later, and how. If nothing yet, say how long the change has
been live.

## What shipped

Merged or not · what you fixed by hand afterwards · did CI pass on the first push?

## What the framework got wrong

Required. Noisy findings, wasted fix loops, misjudged architecture, misleading gate digests,
degradations that should have blocked, friction.

## Artifact links (required — no links, no publication)

- **PR link** (or a redacted diff summary):
- **Run artifacts**: the `.aidd/changes/<id>/` tree or a redacted archive — at minimum
  `prd.md`, `epic.md`, Builder Reports, `qa/verdicts.md`, `qa/test-report.md`,
  `ac-matrix.md`, `supervision/`, and the gates ledger:
- **Benchmark results**, if you ran the harness:
- **CI run link**, if public:

## Attribution

Name, handle, org, or anonymous — anonymous is fine and does not weaken the submission.
