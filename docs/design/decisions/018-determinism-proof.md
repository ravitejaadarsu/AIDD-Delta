# ADR 018 — A gating green is reproduced before it is trusted; a flake proves nothing

**Decision.** Three claim classes must be reproduced before they gate delivery: the full-suite
green the `tests_green` gate rests on, the clean-state E2E green, and any test whose FAIL
closed a fix-loop iteration. Repeat counts come from the rigor mode — `fast` none
(`evidence_reproduced: na`, `reason: rigor:fast`), `standard` the suite twice, `critical` the
suite twice plus the clean-state canonical set twice — and the E2E Verifier performs them
inside its existing QA step 7 dispatch. Runs agree only on identical exit code **and** an
identical test-id → outcome map. A disagreement quarantines the test: it may not serve as
evidence for any AC, gate, or debate defence; every AC it was proving reverts to unproven and
feeds the existing fix loop; it must end `fixed` or human-`accepted` with a recorded reason,
and a `pending` quarantine at G3 forces a human in both autonomy modes. Counting a quarantined
test as green is a supervision VIOLATION, as is re-running a red claim until it comes back
green. New gate: `evidence_reproduced`.

**Why.** This framework's whole claim is evidence over assertion — and then it accepted a
single execution of a stochastic process as proof. A suite that passes once and fails once is
not a passing suite, and the difference matters most exactly where AIDD is most confident: a
fix-loop-closing test's green *is* the evidence the defect is gone, so if that green is a coin
flip, the loop closed on noise and the framework reported certainty it did not have. Two runs
is the smallest number that can detect disagreement at all, which makes 1 → 2 the only step in
the sequence that buys the capability; beyond that, the cheap discriminating checks (fixed
seed, pinned clock, offline, alone, reverse order, parallelism 1) locate the *source* faster
than additional repeats locate the *symptom*, so the third run is spent only once a difference
exists. The retry ban is the load-bearing rule: without it, "reproduce" quietly becomes
"re-run until green", which is worse than not repeating at all because it launders a flake into
evidence.

**Consequence.** The added cost is one extra full-suite run in `standard` and one extra suite
plus one extra clean-state canonical set in `critical` — real wall-clock, and it lands inside a
dispatch that already happens, so it adds no agents and no context. `fast` pays nothing and
says so. The uncomfortable consequence is intended: a project with flaky tests will find that
AIDD stops proving ACs it used to prove, because a quarantined test proves nothing and its ACs
go back to unproven. That will feel like a regression and it is not one — those ACs were never
proven, they were asserted by whichever run landed green. The honest limit is that agreement
proves the *result is stable*, not that the test is *correct*: a test that reliably asserts the
wrong thing passes this protocol untouched, which is why the Auditor's interrogation and the
test debate still run. And where a runner cannot enumerate test ids, the comparison degrades to
exit code plus pass/fail/skip counts, recorded explicitly as a degradation rather than
presented as the full check.
