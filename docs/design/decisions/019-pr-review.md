# ADR 019 — An external PR is reviewed in two phases, and every finding is attacked by a different agent

**Decision.** `/aidd:review-pr` runs a five-phase protocol (`core/protocol/pr-review.md`) over a
pull request the pipeline did not write. **Phase 0** takes ground truth from the commits — the
platform's own PR record (Azure DevOps `az repos pr show`/REST, GitHub `gh pr view --json`) plus
`git merge-base <target> <source>`, with the resolved BASE and HEAD SHAs recorded in the report as
evidence — never from the PR description. **Phase 1** fans out finders **per changed source file**
(a component and its helper bundled as one unit; trivial/cosmetic and E2E/config batched into sweep
agents) *plus* the dimension specialists the repo's `pr_review:` config names, each judging against
the repo's invariants file and the linked ticket. **Phase 2** sends **every** finding to the existing
`core/roles/adversarial-verifier.md` in `mode: pr`, under a mechanical routing rule — a finding is
never verified by the agent that raised it — where the verifier must answer *why* it is a real
problem and *when* it manifests, must **refute** what it cannot trace, **defaults to refuted when
uncertain**, and **sets the severity**. **Phase 3** is one cross-cutting agent holding every artifact
and every verdict. **Phase 4** is a comment validator that drops, rather than softens, any comment
failing factual accuracy, line+side resolution, feed contradiction, or the literal tone list. Three
verdicts are mandatory in every report — **additive**, **non-breaking**, **no hardcodes** — each
`PASS | FAIL | N/A (why)` and proven against the code. Shared-symbol verdicts are per consumer,
proven by importer greps. Nothing is posted without explicit human approval in the current run, in
both autonomy modes.

**Why.** A solo read produces plausible-but-wrong findings and cross-dimension misses at the same
time, and neither is fixable by reading harder — the reader tracing correctness in one file is not
simultaneously holding the shared-package consumers, the platform rules, and the constant drift. The
in-pipeline Reviewer cannot be reused because everything it leans on is absent: no PRD, no story, no
ownership set, no TDD evidence, no Builder Report to interrogate. What replaces that provenance is
ground truth plus adversarial pressure, which is the same trade AIDD already made at QA — so phase 2
reuses the shipped verifier rather than duplicating it, parameterized in four tightenings. Two of
those tightenings are the load-bearing ones and both were learned the expensive way. **Severity
belongs to the verifier** because severity is a claim about impact and the verifier is the one who
just traced it; a finder's CRITICAL on a mechanism that only fires in a dead configuration is a LOW,
and showing both numbers makes the drift visible rather than arguable. **Default to refuted** because
the cost function on someone else's PR is asymmetric: a missed nit costs one nit, and a wrong
CRITICAL costs the credibility that makes every subsequent confirmed finding land. The
trace-the-consumer rule exists for one observed near-miss: a shared `safeCondition` change looked
product-wide breaking by metadata shape, and importer greps showed the submit-sequence executor
evaluated the same key with its own local `resolveCondition` — same key name, two engines, zero real
consumers on the changed path, and the "breaking" change was additive. The three acceptance verdicts
are mandatory-by-format because "we assumed it was additive" is exactly the sentence a review is
supposed to make impossible.

**Consequence.** A PR review costs more dispatches than a read: one per changed source file, plus
sweeps, plus the dimension roster, plus **one verifier per finding** — a 14-finding review is 14
verification units, capped at 6 concurrent. That is deliberate, and it is where the protocol's whole
precision claim lives; capping verification by severity, as QA does, would let exactly the class of
finding this protocol exists to filter reach the author unchallenged. The cost is bounded three ways:
`dispatch.md` caps and queues, rigor mode reduces the specialist roster and sweep granularity, and
per-file units are artifact-disjoint so Tier 1 runs them concurrently. Three limits are honest to
state. First, the review is only as good as the repo's written invariants — a repo with no
`AGENTS.md`, no `CLAUDE.md`, and no constitution gets a review against the code and the ticket alone,
recorded as a degradation. Second, `default to refuted` trades recall for precision by construction:
real defects that cannot be traced from a read will be refuted, and the funnel publishes that number
rather than hiding it. Third, the protocol stops at a post-ready list; a human who never approves the
post gets a report and no PR comments, which is the correct failure mode for a write into someone
else's repository, and the same one `core/protocol/jira-sync.md` already chose for write-back.
