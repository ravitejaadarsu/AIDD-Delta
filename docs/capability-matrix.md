# Capability Matrix

AIDD Delta is portable, but the runtimes it runs on are **not equivalent**. This page names
every capability that actually differs between runtimes, cell by cell, and the
[degradation contract](#the-degradation-contract) names what does not differ at all.

**The same work gets done and the same artifacts are produced on every tier; only speed and
enforcement automation differ — sequential runs take proportionally longer, and
off-Claude-Code the protocol is enforced by discipline plus the Supervisor's audit rather
than by hooks.**

Canonical decision: [ADR 015](design/decisions/015-capability-tiers.md). Portability rules:
[portability.md](portability.md).

## The three tiers

| Tier | Runtime | Defining property |
|---|---|---|
| **Tier 1** | Claude Code, via the `aidd` plugin | Full surface: parallel subagent dispatch through the Task tool, five enforcement hooks, the `/aidd:*` command surface |
| **Tier 2** | Codex CLI | Reads `AGENTS.md` natively, so routing is automatic. Single execution thread; no hooks — every duty a hook automates becomes an explicit orchestrator duty |
| **Tier 3** | Any other agent CLI, or a plain LLM chat session | The playbooks themselves are the interface: paste a prompt from `.aidd/framework/prompts/`. No native routing, no hooks, no parallelism |

Tier is a property of the **runtime**, never of the change. The same change run on all three
tiers must land the same artifacts; a divergence is a bug in the framework, not a tier
difference.

## Capabilities that differ

Legend — **supported**: works as designed · **degraded**: available through the alternative
mechanism named in the cell · **unsupported**: not available at all.

| Capability | Tier 1 — Claude Code | Tier 2 — Codex CLI | Tier 3 — other agent CLI / plain LLM |
|---|---|---|---|
| **Parallel subagent dispatch** (`core/playbooks/00-pipeline.md`) | **supported** — fan-outs (story authors, builders per wave, reviewers per dimension, testers per category, judges) run concurrently as Task-tool subagents, each with its own context window | **degraded** — the identical fan-out set runs sequentially in the documented order; wall clock grows roughly with fan-out width, artifacts are unchanged | **degraded** — same sequential order, and each dispatch is pasted by the operator rather than issued by the runtime |
| **Hook: scope guard** (`hooks/scripts/guard-scope.sh`) | **supported** — `PreToolUse(Write\|Edit)` mechanically blocks writes into `.aidd/framework/` and outside the union of in-progress story ownership sets | **degraded** — the Builder's ownership rule (`core/roles/builder.md`) is the only control; an out-of-scope write is caught after the fact by the disjointness check and the Supervisor's Construction audit | **degraded** — identical to Tier 2 |
| **Hook: pending-gate check on stop** (`hooks/scripts/gate-check.sh`) | **supported** — a session that ends with a pending gate or mid-phase state says so before you walk away | **degraded** — no stop hook; run the status prompt (`AIDD: status`) to see pending gates. Nothing is lost — the gate lives in `state.yaml` — but nothing reminds you | **degraded** — same, via `.aidd/framework/prompts/status.md` |
| **Hook: state schema validation** (`hooks/scripts/validate-state.sh`) | **supported** — `PostToolUse` validates every state write against `core/schemas/*.json` and feeds the error back to the model until it is fixed | **degraded** — the orchestrator must run `python3 .aidd/framework/scripts/aidd-validate.py` itself after each state write, per `core/protocol/state-protocol.md` | **degraded** — same command; if the runtime cannot execute python3, validation degrades to the Supervisor's read of the state file, recorded as a degradation |
| **Hook: snapshot refresh** (`hooks/scripts/build-snapshot.sh`) | **supported** — the Stop hook refreshes `.aidd/context/` opportunistically, on top of the protocol duty | **degraded** — the orchestrator calls `bash .aidd/framework/scripts/build-snapshot.sh <tag>` at every boundary, which is already a duty on every tier (`core/protocol/context-snapshots.md`); a missing pack degrades context, not correctness | **degraded** — identical to Tier 2 |
| **Playwright MCP live re-proof** (`core/protocol/test-debate.md`) | **supported when the Playwright MCP server is connected** — a disputed UI PASS is re-driven in a real browser and the screenshots become the item's evidence. Without the server, Tier 1 takes the same fallback as Tier 2 | **degraded** — the vendored `core/templates/playwright-capture.mjs` script runs the capture; which path ran is recorded in the debate record, never silently skipped | **degraded** — the vendored script where Node exists; otherwise the item degrades to a CLI/API transcript with the reason recorded |
| **Jira MCP pull** (`core/protocol/jira-sync.md`) | **supported when the Atlassian MCP server is connected** — ticket summary, description, and ACs are imported directly | **degraded** — Jira REST with `JIRA_BASE_URL` / `JIRA_EMAIL` / `JIRA_API_TOKEN`, else the operator pastes the ticket text | **degraded** — REST if the runtime can make HTTP calls, else paste the ticket text. AC ids thread identically either way |
| **Plugin command surface `/aidd:*`** (`commands/`) | **supported** — 20 slash commands (`/aidd:go`, `/aidd:approve`, `/aidd:status`, …) | **degraded** — natural-language routing through the `AGENTS.md` managed block: `AIDD: build <intent>`, `AIDD: status`, `AIDD: approve` | **degraded** — paste the matching prompt from `.aidd/framework/prompts/`; approvals can also be recorded by editing `state.yaml` per `core/protocol/gates.md` |
| **Automatic dispatch audit logging** (`hooks/scripts/session-log.sh`) | **supported** — every Task dispatch appends to `supervision/audit.log` without the orchestrator's cooperation, so the log cannot be selectively omitted | **degraded** — the orchestrator appends each line itself per `core/protocol/supervision.md`; the Supervisor cross-checks the log against the artifacts that must exist, so an omission is **detectable** but not **prevented** | **degraded** — identical to Tier 2 |
| **Background / long-running work** | **supported** — a wide fan-out runs to completion inside one session | **degraded** — a long run spans sessions; `state.yaml` is the resume point and the resume prompt re-proves rather than trusts | **degraded** — same, with more manual steps per resume |

## The degradation contract

This is the promise. It is deliberately narrow so that it is testable.

### Identical on every tier

| Guaranteed | Defined by |
|---|---|
| Phase sequence and step order | `core/playbooks/00-pipeline.md` |
| Gate semantics — G1/G2/G3 + `g_test_report`, gate digests, sha256 artifact binding, staleness re-approval | `core/protocol/gates.md` |
| The sixteen quality gates, and their mode-independence | `core/protocol/gates.md` |
| Evidence discipline — command, exit code, trimmed output, or the claim is rejected | `core/protocol/evidence.md` |
| Artifact protocol — roles communicate **only** through artifacts, never live dialogue | `core/playbooks/00-pipeline.md` |
| The state machine and its schemas | `core/protocol/state-protocol.md`, `core/schemas/` |
| Three-layer verification, including interrogation / negotiation / debate budgets | [three-layer-verification.md](three-layer-verification.md) |
| Autonomy-mode semantics | `core/protocol/autonomy-modes.md` |
| Explicit degradation — an unavailable tool is recorded with a reason, never silently skipped | `core/protocol/evidence.md` |

The artifact set is the contract: the same intent run at Tier 3 must produce the same
`prd.md`, `epic.md`, `stories/*`, `qa/*`, `ac-matrix.md`, `supervision/*`, and gates ledger
as at Tier 1, and each must pass the same checks.

### Claude-Code-only

- **Wall-clock parallelism.** Sequential tiers do the same work in more elapsed time,
  roughly proportional to fan-out width. This is the entire performance difference.
- **Mechanical enforcement.** At Tier 1 the hooks *prevent* four classes of protocol
  violation (out-of-scope write, unvalidated state, abandoned gate, missing dispatch log).
  At Tiers 2 and 3 those same rules are protocol duties: the orchestrator is obliged to
  honor them, and the Supervisor's phase-boundary audit *detects* a lapse from the
  artifacts. Prevention becomes detection — a real reduction in guarantee strength, and the
  honest statement of it.
- **The `/aidd:*` command surface**, as an ergonomic affordance over the same prompts.
- **MCP-backed capabilities** (Playwright live re-proof, Jira pull) where the host has the
  server connected. These are host-dependent rather than strictly tier-dependent: a Tier 1
  session without the MCP server degrades exactly like Tier 2.

### What tier does *not* change

Correctness, gate strength, evidence requirements, or what is allowed to ship. No quality
gate is relaxed, waived, or auto-passed because a runtime is Tier 2 or Tier 3. If a tier
cannot produce a required piece of evidence, the run degrades **explicitly** (recorded
reason) or blocks — it never passes on assertion.

## Adding a capability

Per [ADR 015](design/decisions/015-capability-tiers.md), a new capability ships with a row
in this table and a named degradation path for every tier that cannot support it, or it does
not ship. `tests/claims.test.sh` fails if any row in this table leaves a tier column empty.
