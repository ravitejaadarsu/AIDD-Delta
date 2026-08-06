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

**The savings claim is not yet measured.** The design predicts a large token
reduction and a single spot check showed roughly 98% on one symbol read, but a
prediction is not a measurement. `bench/harness.md` is what converts it, and the
ADR 016 rule holds: a cheaper run that finds fewer real defects is a regression,
not a win. Until parity is measured, no cost constant in `cost-governance.md`
should be revised on the strength of this ADR.

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
