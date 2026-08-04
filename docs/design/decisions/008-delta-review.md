# ADR 008 — Delta review is a reviewer mode, not a new role

**Decision.** Pre/post-bound review — judging the Construction diff against what the
pre-phase plan actually meant, and against measured quality drift — is a third mode
(`mode=delta`) on the existing parameterized Reviewer (`core/roles/reviewer.md`), not a
new role. It is dispatched once in QA step 1, alongside the `mode=post` dimension
fan-out, and binds three fixed judgments in that one dispatch — intent-fidelity,
structure-fit, sigma-regression — each producing standard findings rows into
`qa/findings-delta.md`.
**Why.** The repo already parameterizes the Reviewer by mode × dimension (`mode=pre`
judges the plan against the live codebase pre-implementation; `mode=post` judges the
diff post-implementation) rather than forking a `pre-reviewer` and a `post-reviewer`
role. Delta review is the same shape of work — judge an artifact against a reference,
emit severity-ranked findings with a concrete scenario — with a third reference frame
(the pre-phase snapshot pack plus what mode=pre already found the plan to mean). A new
role would duplicate the Reviewer's Protocol, Self-verification, and Report format
sections for no behavioral gain; a third mode reuses all of it and only adds inputs and
judgment bindings.
**Consequence.** `mode=delta` requires snapshot history (`core/protocol/context-snapshots.md`,
ADR 007) to exist — specifically the pre-implementation pack: the latest
`pre-construction` pack under `.aidd/context/history/`, falling back to
`pre-inception` — to judge intent-fidelity and sigma-regression; the pre pack's
`quality-baseline.md` is
the only source for the baseline numbers a sigma-regression finding must cite against
the current pack's numbers. Its findings enter the standard funnel unchanged: collate
(`40-qa.md` step 2) → adversarial verification (step 3) → fix loop (step 6); a finding
without a concrete failure scenario remains invalid by format, same as any other
Reviewer output. When no pre-implementation history pack exists — neither
`pre-construction` nor `pre-inception` (snapshots adopted mid-change) —
`mode=delta` degrades explicitly rather than silently skipping: it reports the missing
pack at the top of `qa/findings-delta.md` and covers only what the remaining inputs
support — structure-fit against the current snapshot — leaving intent-fidelity and
sigma-regression unjudged and said so, not silently dropped.
