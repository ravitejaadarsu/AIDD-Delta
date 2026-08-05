# ADR 014 — Measure the framework instead of asserting it

**Decision.** The repository ships a benchmark harness (`bench/`) rather than benchmark
claims: a corpus of reproducible tasks each carrying a deterministic `oracle`, an
injected-defect catalogue that names the verification layer expected to catch each fault, and
scripts that record tokens and wall-clock into a documented `metrics.json` schema. Three rules
bind it. First, **no fabricated numbers**: every results file in the repository is a template,
an unmeasured cell reads `not measured` (never blank, never zero), and token counts come only
from the runtime's own usage output. Second, **a baseline arm is mandatory for any comparative
claim** — a single agent, one pass, no Layer-1 review fan-out, no Layer-2 adjudication, no
Layer-3 supervision, run over the same tasks with byte-identical intents and graded by the
same oracles. Third, **the harness ships no model and no API key**: every arm is a command the
runner supplies (`--driver aidd|baseline|external:<cmd>`), and `--dry-run` validates the whole
corpus mechanically so CI exercises the harness with no credentials.

**Why.** The framework's most substantial external criticism is that it is unproven: it
asserts precision, three-layer verification, and evidence-over-assertion while shipping zero
measurements. Answering that with numbers a maintainer produced and cannot be re-derived would
repeat the original error at a higher volume. A method a stranger can run on their own hardware
against code they can read is the only answer consistent with `core/protocol/evidence.md` — the
protocol already forbids claiming success without the command, the exit code, and the output,
and the framework itself is not exempt from its own rule. The baseline arm is what turns the
central claim into a testable one: "three-layer verification catches defects ordinary review
misses" is meaningless unless something without those layers ran the same defects through the
same graders, and the verification layers' token cost is only interpretable as a ratio against
that control.

**Consequence.** Publishing a result costs real money and real time: ≥3 repetitions per task
per arm (LLM runs are stochastic, so medians and ranges are reported and no repetition may be
discarded or retried to a better outcome), at least two arms, and an environment capture that
disqualifies a run made from a dirty tree. Tasks pinned to public repositories decay as those
repositories move, so `verified` means only that the SHA was confirmed to exist at pin time and
every task carries a `pretest` that must fail before a run — a task whose behaviour already
exists is recorded `PRETEST-ALREADY-SATISFIED` and excluded rather than counted as a pass. Some
acceptance criteria are honestly not machine-gradeable; those tasks say so, and the report
states which criteria the oracle actually covered. Until somebody runs it, `docs/benchmarks.md`
says plainly that no results are published — which is a weaker marketing position and a
stronger engineering one.
