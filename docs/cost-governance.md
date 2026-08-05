# Cost Governance

Canonical: `core/protocol/cost-governance.md`. Summary:

The rigor mode decides how much verification a change *intends* to buy. Cost governance
measures what it *actually spends*, projects where it will land, and stops the run when it
runs out — instead of quietly buying itself room by verifying less.

## The budget

Two ceilings per change, seeded when the rigor mode resolves:

| rigor mode | `budget_tokens` | `budget_minutes` |
|---|---|---|
| `fast` | 1,600,000 | 30 |
| `standard` | 3,400,000 | 65 |
| `critical` | 5,600,000 | 105 |

These are **derived, not measured**: planned dispatches for the mode × a 40,000-token
per-dispatch allowance. Nothing in this repository has measured a real run's token cost —
`bench/harness.md` is the harness built to produce those numbers. Replace these values with
measured medians once you have them. Every constant is tunable in `constitution.md` under a
`cost:` block.

At G2 the epic resolves, so the story count is real: the framework re-runs the same formula
with the real count. That is a re-derivation, not a raise — it needs no approval, and it is
recorded. Any other ceiling change is a raise and needs a human.

## The ledger

After every dispatch returns, the orchestrator appends one row to `cost/ledger.md`: phase,
dispatch class, role, unit, tokens in/out, wall-clock, running totals, and whether the number
was measured. Where the runtime does not expose usage the row reads `not measured` — never a
zero, never an estimate parked in a measurement column. Wall-clock is always measured, so the
time ceiling is always enforceable.

`spent_tokens` and `spent_minutes` in change state are *derived* from that ledger, never
asserted. Recompute them yourself any time:

```bash
bash .aidd/framework/scripts/aidd-cost.sh                     # the active change
bash .aidd/framework/scripts/aidd-cost.sh --ledger <path>     # a specific ledger
bash .aidd/framework/scripts/aidd-cost.sh --json <metrics-dir>
```

## The projection

Deterministic arithmetic, no model:

```text
projection = spent + Σ (remaining units of a dispatch class × that class's running median)
```

The median is over measured rows of that class in this change's own ledger, with a stated tie
rule (even count ⇒ floored mean of the two middle values) so two runs project identically. A
class with no measured row yet is UNKNOWN and the projection is printed as a **lower bound**
with the unknown count — never rounded up into a total it cannot support.

## Three thresholds

| | trips at | what happens |
|---|---|---|
| soft | 70% of either ceiling, or the projection over budget | one report in the progress line; nothing else changes |
| hard | 100% of either ceiling | STOP and ask — forced-human in both autonomy modes |
| runaway | one dispatch ≥ 5× its class median (or a loop ≥ 3× its planned classes' medians) | that dispatch is aborted and recorded; **no silent retry** |

At a hard stop you get four options and the framework picks none of them for you: raise the
budget, reduce breadth *where the current rigor mode already permits it*, narrow scope, or
abort. The chosen disposition is recorded in `cost.stops` before work resumes.

## What cost may never do

Cost never overrides the floor. A budget stop pauses work for a human decision; it never
skips the TDD evidence, the evidence blocks, the Supervisor, the Critic, the AC matrix, or
your approval at G3 in `let-me-look`.

And the one move that would hide a degraded run is banned outright: **an `na` justified by
cost is forbidden.** A quality gate may record `na` only with `reason: rigor:<mode>` — with
one named carve-out, `within_cost_budget` itself recording `reason: cost:no-dispatches` when
no dispatch ran at all. Any other gate whose `na` reason names cost, budget, tokens, time, or
spend is a supervision violation and the gate reverts to `pending`. Cost pressure produces a
STOP, never a quieter run.

## The gate

`within_cost_budget` — `passed` when the change closed inside its ceilings (including a
recorded, approved raise), `failed` when a hard stop went unresolved, `na` only when no
dispatch ran at all. "We did not track cost" is not an `na`; it is a missing ledger, which the
Supervisor itemizes as a violation.

## Where you see it

The progress line (soft crossings only), the G2/G3 gate digests, the PR body's `## Cost`
section, the dashboard's **Rigor & cost** section (`docs/dashboard.md`), and `/aidd:cost` on
demand.
