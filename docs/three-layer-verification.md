# Three-Layer Verification

Canonical: `core/playbooks/00-pipeline.md`.

AIDD Delta checks a change three times, from three different angles, before it ships.
Each layer answers a different question and none of them trusts the others' word for it.

## The three layers

- **Layer 1 — workers.** Every role that produces the product: Builder, Reviewer, Test
  Engineer, E2E Verifier, Evidence Capturer, AC Assessor, Security Auditor, Adversarial
  Verifier. They write the code, review the diff, design and execute test cases, and
  capture evidence. This layer answers "is the work done?"
- **Layer 2 — adjudicators.** A dedicated Master Agent + Auditor + Tally, talking to each
  other and to Layer 1 only through artifacts — never live dialogue.
  - **Master Agent** (`core/roles/master-agent.md`) monitors work *quality* — is the cited
    evidence convincing, or does it merely gesture at success? Dispatched after every
    construction wave and every QA step batch, over that batch's reports.
  - **Auditor** (`core/roles/auditor.md`) interrogates per-AC *proof* — every claimed
    acceptance criterion must cite executed evidence or it is a gap. Dispatched after
    every construction wave and once as the QA final audit
    (`core/protocol/interrogation.md`).
  - **Tally** (`core/roles/tally.md`) reconciles tracked work items — Jira tickets, PRD
    ACs, stories — against the diff, the tests, and the pre/post evidence. Dispatched
    once in QA, after post evidence and before the Critic.

  This layer answers "is the work *actually proven*, and does it account for every
  tracked item?" — a question Layer 1's own self-report cannot answer credibly.
- **Layer 3 — Supervisor** (`core/roles/supervisor.md`). Dispatched at every phase
  boundary, over the **super-context**: every worker artifact plus `audit/monitoring/*`,
  `audit/interrogation/*`, `audit/negotiation-log.md`, `audit/debate/*`, `qa/tally.md`,
  the Critic verdict, `supervision/audit.log`, and change state. This layer answers "was
  the *process* followed?" — and it also adjudicates any negotiation that exhausts its
  budget, ruling on the disputed AC from that same super-context.

## The amended blocking economy

Before this layer existed, only a CONFIRMED review finding, an executed test FAIL, or a
REJECT critic verdict could block delivery. That set now has one more member: an
acceptance criterion that exits the **interrogation → negotiation → adjudication**
ladder as `DISPUTED` or ruled `DEFECT` blocks via the fix loop, exactly like an executed
FAIL. The ladder is designed to terminate early wherever it honestly can:

- **Interrogation** (`core/protocol/interrogation.md`) closes an AC as `PROVEN` the
  moment cited evidence settles it — most ACs never leave round 1.
- **Negotiation** (`core/protocol/negotiation.md`) never even opens if the Master
  Agent's monitoring note already agrees the work is deficient — the **short-circuit**
  rule sends the AC straight to the fix loop as a `DEFECT`, no position, no response.
  A DISPUTED AC with no monitoring note covering the subject also short-circuits
  straight to the fix loop, recorded as one negotiation-log line (who ruled: short-circuit).
- Where negotiation does open, the Master Agent's **accept** response closes it
  immediately as `DEFECT` — no adjudication follows. Only a **contest** that survives
  both budgeted exchanges reaches the Supervisor.

Layer-2 output that carries no AC mapping — a monitoring concern about style, debate
records on non-AC items — is advisory, never a blocker. Only a per-AC verdict blocks.

## Worked example: a disputed AC travels the full ladder

Story `STORY-042` claims AC-3 ("cart total recalculates when an item's quantity changes
to zero") done. Its Builder Report cites a test that mocks the pricing service instead of
exercising it.

1. **Interrogation, round 1.** The Auditor reads the Builder Report, finds AC-3's
   evidence is a mocked test, and writes
   `audit/interrogation/STORY-042-round1-challenge.md`: "AC-3 evidence gap — the cited
   test stubs `PricingService.recalculate`; run the real quantity-to-zero flow and paste
   the resulting cart total." The orchestrator re-dispatches the Builder to respond.
2. **Weak response.** The Builder's round-1 response carries an evidence block, but it
   re-cites the same mocked test rather than the real flow the challenge demanded — it
   doesn't settle AC-3. Budget remaining, the Auditor carries AC-3 into round 2 and writes
   the round-2 challenge repeating the demand.
3. **Interrogation, round 2 — DISPUTED.** The round-2 response still doesn't run the real
   flow. Round 2 is final: the Auditor writes
   `audit/interrogation/STORY-042-verdict.md` marking AC-3 `DISPUTED` with the named gap.
4. **Negotiation opens.** This wave's Master Agent monitoring note
   (`audit/monitoring/construction-wave-2.md`) already found STORY-042's work
   *acceptable* — so the short-circuit rule does not apply, and negotiation opens per
   `core/protocol/negotiation.md`. The Auditor's position (exchange 1) restates the
   evidence gap. The Master Agent is re-dispatched and **contests**, standing by the
   mocked-test result as sufficient. Exchange 2: the Auditor's position is unchanged; the
   Master Agent **contests** again.
5. **Budget exhausted → Supervisor adjudicates.** Two exchanges are spent and the Master
   Agent is still contesting, so the Supervisor adjudicates from the super-context — not
   from the exchanged positions alone. Reading the actual pricing-service code path
   alongside both artifacts, the Supervisor rules `DEFECT`: the mocked test never proves
   the real recalculation. It appends one line to `audit/negotiation-log.md` (who ruled:
   Supervisor adjudication).
6. **Fix loop.** AC-3's `DEFECT` re-enters the story's remediation ladder — story back to
   `ready`, one re-dispatch — the same as any other fix-loop defect. The Builder writes
   the real quantity-to-zero test first (TDD: red, confirming it fails against the mock
   removal), then implements against the live `PricingService`, and reproves AC-3 with
   the test now green against real behavior.

Every step above is exactly one artifact write; nothing in this ladder is a live
conversation between roles.

## Budgets

- Interrogation: max **2** challenge rounds per subject.
- Negotiation: max **2** exchanges per disputed AC.
- `UNRESOLVABLE` — the super-context genuinely doesn't settle the AC — forces a human
  stop in both autonomy modes, take-care included.

See also: [ADR 006](design/decisions/006-three-layer-verification.md),
[Supervision](supervision.md).
