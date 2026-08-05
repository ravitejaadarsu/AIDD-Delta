# AIDD Pipeline — the canonical contract

Every runtime (Claude Code, Codex CLI, any agent CLI) follows this file exactly.
Never improvise phase logic: each phase's rules live in its playbook; shared rules live
in `../protocol/`.

## Phase sequence

document (brownfield, once, optional) → master (once) → inception → construction → qa →
delivery → retro → done. Strict order per `../protocol/state-protocol.md`.

## The orchestrator (you, the main session)

- Owns and is the ONLY writer of `.aidd/state.yaml` and `changes/<id>/state.yaml`.
- Dispatches every role in `../roles/` (Claude Code: parallel subagents via the Task tool;
  other runtimes: sequentially in the documented order — results must be order-independent
  because roles communicate only through artifacts).
- Runs the mechanical checks (disjointness, TDD-evidence, gate hashes), operates gates
  per `../protocol/gates.md`, runs bounded fix loops, appends to the supervision audit
  log per `../protocol/supervision.md`, regenerates `dashboard.html` after every state write
  (`.aidd/framework/scripts/render-dashboard.sh` when present).
- Rebuilds the snapshot pack at every phase boundary
  (`bash .aidd/framework/scripts/build-snapshot.sh pre-<phase>` per
  `../protocol/context-snapshots.md`) + measured-sigma append per
  `../protocol/context-snapshots.md`.
- Never writes product code or product artifacts itself.

## Rigor mode

How much verification the change earns is decided ONCE, mechanically, by the classifier in
`../protocol/rigor-modes.md` — at change creation, before Inception. The resolved mode
(`fast` | `standard` | `critical`, default `standard`) is recorded in change state under
`rigor` (`mode`, `selected_by`, `reason`), echoed in the orchestrator's progress line, and
carried into the G2/G3 gate digests and the PR body. Rigor is orthogonal to the autonomy
mode: autonomy decides who approves, rigor decides how much runs. Escalation is one-way and
automatic (`fast` → `standard` → `critical`) whenever mid-run evidence says the change is
riskier than its mode; de-escalation does not exist. Every step a mode skips is recorded
`na` with `reason: rigor:<mode>` — never silently absent. The floor in `rigor-modes.md`
(TDD evidence, disjoint ownership, evidence blocks, the Supervisor audit, the Critic
verdict, human approval at G3 in `let-me-look`) holds in every mode.

## Dispatch is table-driven

Agent count, ownership, parallel-vs-sequential, cap and order come from the decision table
in `../protocol/dispatch.md` — one lookup per step, never a fresh judgment. The orchestrator
records the resolved plan in `supervision/audit.log` and does not revisit it within the
step; re-deciding mid-step is a supervision VIOLATION. Parallel dispatch requires provably
pairwise-disjoint ownership sets (`../protocol/file-scope.md`); unproven ⇒ sequential in the
row's documented order.

## Cost governance

Rigor decides how much verification the change intends to buy; `../protocol/cost-governance.md`
governs what it actually spends. Two ceilings (`cost.budget_tokens`, `cost.budget_minutes`)
are seeded from the rigor mode at change creation and re-derived once at G2 from the resolved
epic. **The orchestrator's recording duty: after every dispatch returns, before the next one
starts, append one row to `cost/ledger.md`** (`../templates/cost-ledger.md`) and fold it into
`cost.spent_*` and `cost.by_phase` — a runtime that exposes no usage records `not measured`,
never a zero. The projection is arithmetic (remaining planned dispatches × the running median
of that dispatch class), recomputed after every append. Soft (70%) reports inside the progress
line's `<what happened>` field; hard (100%) STOPs and asks — forced-human in both autonomy
modes; runaway (a dispatch ≥ 5× its class median) aborts that dispatch and records it, never
retrying silently. Cost never overrides the floor, and **an `na` justified by cost is
forbidden**: cost pressure produces a STOP, never a quieter run. Gate: `within_cost_budget`.

## Three verification layers

- **Layer 1 — workers**: every role that produces the product (Builder, Reviewer, Test
  Engineer, Verifier, Evidence Capturer, AC Assessor, Security Auditor, Adversarial
  Verifier).
- **Layer 2 — adjudicators**: Master Agent (`../roles/master-agent.md`) monitors work
  quality, dispatched after every construction wave and every QA step batch; Auditor
  (`../roles/auditor.md`) interrogates per-AC proof (`../protocol/interrogation.md` →
  `../protocol/negotiation.md`), dispatched after every construction wave and once as the
  QA final audit; Tally (`../roles/tally.md`) reconciles tracked work items, dispatched
  once in QA (after post evidence, before the Critic).
- **Layer 3 — Supervisor** (`../roles/supervisor.md`), dispatched at every phase boundary,
  audits process compliance over the **super-context**: all worker artifacts +
  `audit/monitoring/*` + `audit/interrogation/*` + `audit/negotiation-log.md` +
  `audit/debate/*` + `qa/tally.md` + the Critic verdict + `supervision/audit.log` + change
  state; it also adjudicates negotiations that exhaust their budget.

## Starting a change

1. If `.aidd/state.yaml` reports `constitution: missing` → run `10-master.md` first.
2. Create `changes/<YYYY-MM-DD>-<slug>/` from templates (`change-state.yaml`, `intent.md`);
   record the verbatim intent, mode (inherit `default_mode` unless the user chose), and
   Jira ticket if referenced. Run the rigor classifier (`../protocol/rigor-modes.md`) over
   the intent and record the resolved `rigor` block. Set `active_change`.
3. Create working branch `aidd/<change-id>`.
4. Run phases in order: `20-inception.md` → `30-construction.md` → `40-qa.md` →
   `50-delivery.md` → `60-retro.md`.
5. At every phase boundary: dispatch the Supervisor (`../roles/supervisor.md`).
   A VIOLATIONS verdict blocks advance until remediated.

## Resume

`../protocol/state-protocol.md` §Resume. Always re-prove, never trust.

## Invariants (all phases)

- Artifacts are the only inter-agent channel.
- Evidence over assertion (`../protocol/evidence.md`).
- Bounded loops; exhaustion → blocked, never infinite retries.
- Quality gates are mode-independent (`../protocol/gates.md`).
- Every dispatch is metered (`../protocol/cost-governance.md`); a budget stop pauses work for
  a human decision and never reduces verification.
