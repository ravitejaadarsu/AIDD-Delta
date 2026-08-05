# ADR 017 — A defect that escapes is analyzed per layer, and the framework records its own blindness

**Decision.** When a defect is found after merge, `/aidd:escape` attributes it to the AIDD
change that produced it and dispatches a new adjudicative role, the Escape Analyst
(`core/roles/escape-analyst.md`), which produces a **mandatory nine-row per-layer verdict
table** — `L1-review`, `L1-tests`, `L2-auditor`, `L2-tally`, `L2-debate`, `L3-supervisor`,
`critic`, `e2e-mutation`, `evidence-capture` — each row carrying `should_have_caught`, `did`,
`why_missed` (citing the blind artifact by path), and `preventable_by` (one minimal change to
a named file). Two outputs are mandatory: a permanent **regression test** authored TDD inside
the fix change, and one **protocol amendment proposal** recorded in the report and in
`learnings.md`. Amendments are proposals; no agent applies one. `no layer could have caught
this at reasonable cost` is a supported verdict with a required cost argument. Escape rate and
per-layer blindness are recorded in `.aidd/escapes/register.md` as the counter-metric to every
detection claim. Repeat escapes escalate to a human instead of re-proposing.

**Why.** Verification frameworks are graded on what they catch, and they grade themselves the
same way, which is how a field ends up with unfalsifiable detection claims and no published
misses. Forward verification also cannot see its own blind spots by construction: the layer
that missed a defect is exactly the layer that will report nothing about it. Something had to
walk the merged change backward against a known ground truth — the defect — and the only way
to keep that from becoming vibes was to make the table mandatory and every cell format-checked,
so "we didn't consider Layer 2" is not expressible. The `did: yes` column exists because the
most dangerous escape is the one the framework *caught* and then dropped at a disposition:
refuted by adversarial verification, waived at a gate, ruled away in negotiation. A per-layer
count of misses is also the only honest denominator for the framework's own claims, which is
why it lives in the same vocabulary as `bench/`'s injected defects.

**Consequence.** The capability costs one adjudicative dispatch per escape — a genuinely
expensive one, because the Analyst must open every artifact rather than reason about them —
plus a fix change that carries the regression test at no less than the escaped change's rigor
mode. That is deliberate: the alternative is an escape closed by an assertion. It also costs a
standing register whose numbers will, by design, make the framework look worse than a
detection-only report would; that is the point, and any document quoting a detection number
has to be readable next to it. Two limits are honest to state. First, attribution is only as
good as the git history: code an AIDD change never touched is recorded `out-of-scope` rather
than force-fitted into a verdict. Second, amendments accumulate as *proposals*, and a human who
never reads them gets no benefit — the framework refuses to apply them itself because a system
that rewrites its own rules per incident accretes unreviewed rules faster than anyone can
audit them, and the rules are the whole product.
