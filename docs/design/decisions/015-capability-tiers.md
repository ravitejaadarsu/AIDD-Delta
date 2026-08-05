# ADR 015 — Publish capability tiers and a degradation contract, not a flat portability claim

**Decision.** Runtime support is published as three named tiers with a per-capability matrix
(`docs/capability-matrix.md`) plus an explicit **degradation contract**, replacing the flat
"any agent CLI runs literally the same playbooks" claim as the public statement of
portability. Tier 1 is Claude Code (parallel Task-tool dispatch, five enforcement hooks, the
`/aidd:*` command surface); Tier 2 is Codex CLI (native `AGENTS.md` routing, single execution
thread, no hooks); Tier 3 is any other agent CLI or a plain LLM session (prompts pasted from
`.aidd/framework/prompts/`). The contract states what is identical on every tier — phase
sequence, gate semantics, the fourteen quality gates, evidence discipline, the
artifacts-only channel, the state machine, three-layer verification and its budgets, explicit
degradation — and what is Claude-Code-only: wall-clock parallelism, and mechanical hook
*prevention* of protocol violations where other tiers have protocol duty plus the
Supervisor's *detection*. Every capability claim in the docs must name its tier.

**Why.** ADR 001 is still correct — one portable source of phase logic, with Claude-specific
power additive and never semantic. But the way that decision was *marketed* drifted past what
it says. "Any agent CLI runs literally the same playbooks" is true of the playbooks and false
as a statement about operating the framework: a reader reasonably inferred operational
equivalence, then discovered that a fan-out which takes one wave on Claude Code takes N
sequential dispatches elsewhere, and that the four hook-enforced invariants are, off Claude
Code, promises rather than mechanisms. Implied equivalence was also **untestable** — there
was no artifact a test could point at to check whether a claim about a runtime was true. A
tier table is falsifiable per cell; "portable" is not. Naming the gap is also strictly
stronger as an argument: the interesting claim was never "it runs anywhere identically", it
is "the semantics and the artifacts are identical anywhere, and only speed and enforcement
automation differ" — which is a claim worth trusting because it is narrow.

**Consequence.** Three ongoing obligations. First, **every capability claim names its tier**;
a docs sentence asserting a capability without a tier is a defect, and Tier-1-only
capabilities carry that badge in `README.md`. Second, **a new capability ships with its tier
row and a named degradation path** for every tier that cannot support it, or it does not ship
— `tests/claims.test.sh` fails when a matrix row leaves a tier column empty, which makes the
obligation mechanical rather than cultural. Third, **Tier 2 parity work is now visible**:
the matrix's degraded cells are the roadmap of what could be closed (a Codex-side scope
guard, an orchestrator-side validation wrapper), and closing one means editing a cell rather
than re-litigating portability. The cost is a maintenance surface — the matrix is a second
place that must change when the plugin surface changes — accepted because the alternative
(an equivalence claim nobody can check) already cost the project credibility. This ADR
refines ADR 001; it does not overturn it. The portable core remains the product, and
sequential fallback must still converge on identical artifacts — that convergence is now
written down as a contract instead of assumed.
