# ADR 009 — Test debate is continuous across three surfaces, under one hard budget

**Decision.** Test designs and test results are contested on **three** surfaces of the QA
testing pass, not once at the end (`core/protocol/test-debate.md`): **design** — Test
Engineers publish their TC matrices before executing anything and the Master Agent + Auditor
challenge coverage in one batched challenge artifact (`core/playbooks/40-qa.md` step 4);
**execution** — the
Auditor contests specific TCs as each category's results land and the owning tester
re-executes only those (inside step 5); **results** — disputed PASSes in the consolidated
`qa/test-report.md` are re-proven **live** through **Playwright MCP** browser runs for
UI-facing flows, with the screenshots as the item's evidence, and CLI/API transcripts
otherwise (step 10). One exchange is one challenge artifact plus its response, as a pair; a
batched round covering every category counts as **1 exchange**. Per-surface caps are 2 / 2 / 2
under a shared pool of **6 exchanges per change** that strictly dominates them, drawn in
pipeline order, with no rollover of unused exchanges. Every debate item cites the AC id(s) the
contested test evidences; the orchestrator sets `debate_complete` when all three surfaces
close within budget, and is its only setter.
**Why.** The user chose full continuous debate over a single end-of-QA challenge: precision
over speed. A weak test design caught at step 4 costs one exchange; the same weakness found
after eight categories have executed costs the whole execution spend plus a fix loop, and
found in production costs more again. This is the same economy the repo already runs on ADR
004 (only adversarially-confirmed findings block) and ADR 006 (a Layer-2 challenge that
cannot survive counter-evidence must not stop delivery) — applied to the tests themselves
rather than to review findings, because a PASS is only worth what its assertion actually
proves. Live re-proof exists for the same reason: re-citing the original run defends nothing
if the run was the thing in doubt.
**Consequence.** Up to **6 extra adjudicative exchanges per change** on top of Layer 2's
interrogation and negotiation budgets, and testers now block on a debate verdict before
executing — design-time latency traded for execution-time waste. The caps are hard, so the
worst case is bounded and knowable: 2+2+2 fully subscribes the pool, and the pool wins
wherever a surface still has allowance left. Exhaustion has an exit rather than a loop — an
item still contested when its allowance or the pool is spent marks its mapped AC(s)
**DISPUTED** and enters the existing negotiation ladder (`core/protocol/negotiation.md`) as a
normal disputed AC, terminating in `PROVEN | DEFECT | UNRESOLVABLE`; a contested item with no
AC mapping (a `performance-smoke` observation, say) is advisory and never blocks, consistent
with ADR 006's blocking economy. Runtimes without Playwright MCP degrade **explicitly** to the
vendored `core/templates/playwright-capture.mjs` script, with which path ran recorded in the
debate record — never a silent skip of the live re-proof. Debate outcomes that invalidate a
test design feed `learnings.md` like REFUTED findings do, so the next run designs better
matrices rather than re-litigating the same gap.
