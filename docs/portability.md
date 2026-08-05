# Portability

**The portable core is the product; the Claude Code plugin is a thin shell.** That is still
true — but it is not a claim of operational equivalence between runtimes. Portability here
means *identical semantics and identical artifacts*, on three explicitly named tiers with
different speed and different enforcement.

Per-capability detail: [capability-matrix.md](capability-matrix.md). Decision:
[ADR 015](design/decisions/015-capability-tiers.md), refining
[ADR 001](design/decisions/001-portable-core.md).

## The three tiers

- **Tier 1 — Claude Code** (the `aidd` plugin). Fan-outs run as parallel Task-tool
  subagents, each with its own context window. Five hooks mechanically enforce protocol
  invariants: scope guard, state schema validation, pending-gate check on stop, snapshot
  refresh, dispatch audit logging. The `/aidd:*` slash commands are the operator surface.
- **Tier 2 — Codex CLI.** Codex reads `AGENTS.md` natively, so the routing table installed
  by `install.sh` makes natural language work (`AIDD: build <intent>`, `AIDD: status`).
  Single execution thread: every fan-out runs sequentially in the documented order. No
  hooks — each of the four hook-enforced invariants becomes an explicit orchestrator duty,
  audited after the fact by the Supervisor.
- **Tier 3 — any other agent CLI, or a plain LLM chat session.** The playbooks are the
  interface: paste the matching prompt from `.aidd/framework/prompts/` (`go`, `status`,
  `resume`, or a phase prompt). No native routing, no hooks, no parallelism. Gate approvals
  can be recorded by editing the change's `state.yaml` per `core/protocol/gates.md` — state
  files are human-editable by design.

Tier is a property of the runtime, not of the change. A change begun at Tier 1 can be
continued at Tier 3 and vice versa: the target repo is self-contained.

## What portability actually guarantees

**The same work gets done and the same artifacts are produced on every tier; only speed and
enforcement automation differ.** Sequential runs take proportionally longer, and
off-Claude-Code the protocol is enforced by discipline plus the Supervisor's audit rather
than by hooks. Nothing else moves:

- All phase logic, gate semantics, state protocol, roles, templates, and schemas live in
  `core/` as plain markdown/YAML/JSON — vendored into every target repo at
  `.aidd/framework/`.
- The plugin layer (`commands/`, `agents/`, `skills/`, `hooks/`) only *references* the
  vendored core. If logic appears in both places, that is a bug (see `CONTRIBUTING.md`).
- Fan-outs degrade to sequential execution in the documented order. Roles communicate only
  through artifacts, so parallel and sequential runs converge on identical outputs — the
  convergence requirement of [ADR 001](design/decisions/001-portable-core.md), now written
  down as the degradation contract rather than assumed.
- No quality gate is relaxed, waived, or auto-passed because of the tier. Where a tier
  cannot produce a required piece of evidence, the run degrades **explicitly** with a
  recorded reason, or it blocks (`core/protocol/evidence.md`).

## What it does not guarantee

- **Equal wall-clock time.** A Construction wave with five builders is one wave at Tier 1
  and five sequential dispatches at Tiers 2 and 3.
- **Equal enforcement strength.** At Tier 1 an out-of-scope write, an unvalidated state
  write, an abandoned gate, and a missing dispatch-log line are *prevented*. At Tiers 2 and
  3 they are *detected* by the Supervisor's phase-boundary audit. Prevention and detection
  are not the same guarantee, and the matrix says which you are getting.
- **Equal tool access.** Playwright MCP live re-proof and Jira MCP pull depend on connected
  MCP servers; without them, both degrade along documented paths (see the matrix). A Tier 1
  session without those servers degrades exactly like Tier 2.

## Runtime dependencies

The only hard runtime dependencies anywhere: **bash + python3 (stdlib)**. Playwright,
mutation tools, and security scanners are optional and degrade explicitly
(`core/protocol/evidence.md`).
