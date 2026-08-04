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
  `../protocol/context-snapshots.md`).
- Never writes product code or product artifacts itself.

## Starting a change

1. If `.aidd/state.yaml` reports `constitution: missing` → run `10-master.md` first.
2. Create `changes/<YYYY-MM-DD>-<slug>/` from templates (`change-state.yaml`, `intent.md`);
   record the verbatim intent, mode (inherit `default_mode` unless the user chose), and
   Jira ticket if referenced. Set `active_change`.
3. Create working branch `aidd/<change-id>`.
4. Run phases in order: `20-inception.md` → `30-construction.md` → `40-qa.md` →
   `50-delivery.md` → `60-retro.md`.
5. At every phase boundary: dispatch the Master Supervisor (`../roles/master-supervisor.md`).
   A VIOLATIONS verdict blocks advance until remediated.

## Resume

`../protocol/state-protocol.md` §Resume. Always re-prove, never trust.

## Invariants (all phases)

- Artifacts are the only inter-agent channel.
- Evidence over assertion (`../protocol/evidence.md`).
- Bounded loops; exhaustion → blocked, never infinite retries.
- Quality gates are mode-independent (`../protocol/gates.md`).
