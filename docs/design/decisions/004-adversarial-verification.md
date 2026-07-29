# ADR 004 — Only adversarially-confirmed findings block

**Decision.** Every CRITICAL/HIGH review finding goes to a verifier whose explicit
incentive is to REFUTE it. CONFIRMED blocks; PLAUSIBLE demotes to advisory; REFUTED drops
(and feeds learning).
**Why.** Reviewer over-flagging is the dominant failure mode of AI review. Precision is
the brand: a finding that cannot survive a motivated skeptic must not stop delivery.
**Consequence.** QA cost rises (extra verification pass); wasted fix-loop iterations and
false blocks fall. The findings funnel (raised → confirmed → fixed → refuted) is
published in every PR body.
