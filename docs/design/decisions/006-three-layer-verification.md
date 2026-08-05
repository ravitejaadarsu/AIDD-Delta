# ADR 006 — A dedicated Layer-2 adjudicates AC proof, not just process

**Decision.** A third verification layer sits between the workers (Layer 1: Builder,
Reviewer, Test Engineer, Verifier, Evidence Capturer, AC Assessor, Security Auditor,
Adversarial Verifier) and the process auditor (Layer 3: Supervisor, renamed from Master
Supervisor in v0.3.0 — see the amendment on ADR 005). Layer 2 is a dedicated Master Agent

+ Auditor + Tally, communicating only through artifacts: the Master Agent monitors work
quality after every construction wave and QA step batch; the Auditor interrogates
per-AC proof (`core/protocol/interrogation.md`) after every construction wave and once as
the QA final audit, escalating a DISPUTED AC to negotiation with the Master Agent
(`core/protocol/negotiation.md`); Tally reconciles tracked work items once in QA. The
blocking economy is amended: an AC that exits the interrogation → negotiation →
adjudication ladder as **DISPUTED** or ruled **DEFECT** blocks via the fix loop, same as
an executed test FAIL. The ladder can terminate early — the Master Agent's **accept**
skips adjudication and rules `DEFECT` directly; the short-circuit rule (the monitoring
note already concurs the work is deficient) skips negotiation entirely; a DISPUTED AC with no monitoring note covering the subject also short-circuits straight to the fix loop. Layer-2 output
with no AC mapping — a monitoring concern, debate records on non-AC items — is advisory; only a
per-AC verdict blocks.
**Why.** Precision over speed: an AC gap caught per wave, while the story's context is
still live, is cheap to fix; the same gap found at final QA or in production is not. This
extends the reviewer over-flagging economy (ADR 004 — only adversarially-confirmed
findings block) to acceptance-criteria disputes: an Auditor challenge that cannot survive
the Master Agent's counter-evidence, and ultimately the Supervisor's adjudication, must
not stop delivery either.
**Consequence.** Roughly two adjudicative dispatches per construction wave (Master Agent
monitor + Auditor interrogation) plus one QA batch cost (Auditor final audit, Tally,
and any negotiations they trigger). Hard budgets cap the worst case: max **2**
interrogation rounds per subject, max **2** negotiation exchanges per disputed AC.
**UNRESOLVABLE** — the Supervisor's super-context genuinely fails to settle a disputed
AC — forces a human stop in both autonomy modes, take-care included.
