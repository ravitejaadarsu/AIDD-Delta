# ADR 020 — Manage the execution environment, not just the prompts

Status: accepted · Supersedes nothing · Extends ADR 002 (zero-dep), ADR 007
(context snapshots), ADR 016 (cost governance)

## Context

The framework's cost curve was set by how much source text reached the model.
Roles read whole files to find one function, verifiers received file bodies to
judge a small diff, and raw test logs went to a role in full. All three are the
same mistake in different clothes: sending text to answer a question that could
have been answered locally.

Two further gaps were structural rather than economic. Agent-issued test
commands ran on the host, so a wrong expansion in a generated command could
damage the working tree. And every dispatch ran on one model tier, so a
mechanical rename cost the same as an adversarial verification.

## Decision

Shift from *read everything* to *query locally*, and make the local environment
a managed surface:

1. **A dual-state index** (`aidd-index.py`) records, per file, the symbols a
   parser found **and** the git blob hash of the bytes they came from.
2. **Just-in-time reads** (`aidd-read-block.py`) serve one symbol plus its
   signature-scoped type dependencies, hashing before serving.
3. **Verification carries a patch**, not file bodies; context is pulled on demand.
4. **Test logs are redacted** (`aidd-redact-log.py`) to error type, assertion,
   and `file:line`, with the reduction ratio reported.
5. **Test execution is sandboxed** (`aidd-sandbox.sh`) in a disposable container.
6. **Dispatch classes route to models** via `.aidd/config.json`.
7. **The framework triggers itself** via a pre-commit hook and a PR workflow.

## Consequences

**The hash is the load-bearing part.** Structure alone is a cache with no
invalidation story: a span is valid only for the exact bytes it was parsed from.
Every consumer therefore compares hashes before believing a span, which is what
makes "reparse only what moved" safe rather than merely fast.

**Tree-sitter is an accelerator, never a dependency.** ADR 002 forbids hard
third-party dependencies, so the index falls back to per-language extractors,
and any file no parser understands still gets a path-and-hash entry. Structure
is optional; knowing whether a file changed is not.

**Redaction is subtractive-by-default and signal-gated.** The naive framing —
compress as much as possible — produces the worst possible failure: a redactor
that eats the real error, with no way for the reader to tell. The inversion (any
line carrying an error, assertion, or `file:line` is never dropped; duplicates
collapse *with a count*; unknown formats are labelled) costs compression ratio
and buys the only property that matters.

**Two config files is a deliberate cost.** `.aidd/config.json` splits
configuration across two surfaces, which is a real downside. The boundary is the
approval requirement: `constitution.md` holds what a human must approve;
config.json holds what a script reads on every dispatch. Machine-tunable routing
in a human-approval file would either require approval for every tuning change
or erode the meaning of approval. Credentials never appear in either — the audit
fails the run on a credential-shaped entry.

**Degradation is loud everywhere, and this is the recurring theme.** No
container runtime, no tree-sitter, no index, no configured rate: in every case
the run continues and says so. The alternative — silent fallback — produces a
caller that believes it was isolated, or parsed, or measured, when it was not.
`AIDD_SANDBOX_REQUIRED=1` exists for callers who would rather fail than degrade.

**Context cost is measured in bytes; tokens and parity are still not.** The
`bench-context.py` arm (`bench/harness.md`) measures both read strategies
over the same deterministic target set, with no credentials and no model call. On
this repository — 173 symbols across 48 files — the query path reads **70.9%
fewer bytes** than reading whole files, or **47.6% fewer** once the index's fixed
cost is charged. Measured from a clean tree at `54644f7`, which is what makes the
figure quotable — the metrics object records `framework_tree_dirty`, and a dirty
run is disqualified.

The run output is deliberately **not committed**: this repository publishes no
measured results (`bench/results/TEMPLATE.md`), and `tests/bench.test.sh`
enforces that `bench/results/` ships no run output. A number that ships as a file
becomes a claim nobody re-checks; a number that ships as a command stays
falsifiable. Reproduce with:

```bash
python3 bench/scripts/bench-context.py
```

Those corpus numbers replace the headline the design was first argued from. A
single symbol pulled from a large file shows roughly 98% reduction, and quoting
that as the framework's number would have been a sample-of-one dressed up as a
result — the honest figure is roughly half to two-thirds, depending on whether
the index is amortized.

**The reduction can also be negative, and the benchmark reports it.** Spans are
charged per target while a whole-file read is charged once, so *many symbols from
one small file* costs more via spans than simply reading the file. Querying wins
where files are large and the needed slice is small; it loses where files are
small and most of the file is wanted. That bounds the pivot's claim honestly: a
large win on service-sized code, a wash or a loss on small modules.

**Tokens are now measured too, and they are less flattering than bytes.** Running
`bench-context.py --tokens` weighs both payloads through the agent CLI and reads
its own usage output — three calls, a control plus each arm, with the control
subtracted so what remains is the payload's own cost. On a 60-symbol sample from
a clean tree: **93,024 to 46,130 prompt tokens, a 50.4% reduction**, for $2.06 of
measurement.

Two things that number must be read against, or it will be quoted wrongly:

- **The weighed query payload includes the index**, so 50.4% is comparable to the
  index-amortized byte figure (56.2% on the same sample), **not** to the
  spans-only 87.4%. Pairing the spans-only byte figure with a token claim would
  overstate the saving by roughly 37 points.
- **Tokens reduce less than bytes.** JSON tokenizes worse than prose, so the
  index costs proportionally more in tokens than its byte size implies. The byte
  measurement is an upper bound on the token saving, not a proxy for it.

**Defect-detection parity was measured, and found no regression — on a corpus too
easy to prove much.** `bench-parity.py` injects one defect, sends the same
instruction to both arms (whole file vs index plus the changed symbol's span), and
grades mechanically: caught iff a reported line falls inside the injected span.
Three defect shapes, three reps each, both arms:

| Shape | Baseline | Query |
| --- | --- | --- |
| local — assertion inverted inside the span | 3/3 | 3/3 |
| non-local — shared helper inverted | 3/3 | 3/3 |
| subtle-non-local — helper silently no-ops | 3/3 | 3/3 |

18/18, $4.22 to measure. No defect was lost by reading spans, including the case
built specifically to punish spans: a three-line helper that reads as a plausible
early return in isolation while silently disabling every assertion in the file.

**The result's own weakness matters more than the result.** The baseline never
dropped below 100%, so the experiment has **no discriminating power** — it shows
the query arm does not lose defects at this difficulty, and says nothing about
behaviour near the detection threshold. Parity here is *unfalsified on this
corpus*, not *established*.

**No cost constant in `cost-governance.md` has been revised**, and this evidence
does not license one. Three defects in one 194-line fixture is not the graded
`bench-run.sh` corpus that ADR 016 requires, and a probe where nothing failed
cannot distinguish "the arms are equal" from "the test was too easy". Moving a
constant needs a run whose baseline arm misses defects some of the time.

## Alternatives considered

- **Full LSP integration** — more precise than either parser, but a hard
  dependency on a language server per stack, which ADR 002 rules out.
- **Embedding-based retrieval** — returns plausible neighborhoods rather than
  exact spans, and cannot answer "did this file change" at all.
- **Routing config inside `constitution.md`** — one config surface, but either
  every model-tier tweak needs human approval or approval stops meaning anything.
- **Sandboxing the whole orchestration** — stronger isolation, but it puts the
  framework's own file writes behind a container boundary for a threat model
  (generated *test commands*) that only needs the test runner contained.
