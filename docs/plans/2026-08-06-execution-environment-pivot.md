# Execution-Environment Pivot

Move AIDD Delta from *managing prompts* to *managing the local execution environment*.

The thesis: today the framework's cost curve is set by how much source text reaches the
model. Replace "read everything" with "query locally via tools" — the model reads a
structural index, then pulls only the exact spans it needs.

```text
Current loop:   [full files + full test logs + large role prompts] -> model  -> large bill
Target loop:    [AST index] -> model reads structure -> read_block(file, sym) -> small footprint
```

## Standing context

- Repo is markdown + bash with a handful of Python scripts. No dependency manifest, so
  language detection is `unknown`; reviewer duties fall to the generic reviewer.
- `core/protocol/context-snapshots.md` already ships a **prose** snapshot pack built by
  `core/scripts/build-snapshot.sh`. The AST index extends that surface — it does not
  replace it.
- Per-repo configuration today lives in `constitution.md` blocks (`cost:`, `pr_review:`).
  Introducing `.aidd/config.json` splits the configuration surface; Step 1 must decide
  whether to adopt JSON, or express model routing as a `models:` block in `constitution.md`.
- No container, sandbox, pre-commit, or model-routing surface exists in the repo today.
  Steps 6, 7, and 8 are greenfield.
- `tests/run.sh` is the canonical test entrypoint; `scripts/check-refs.sh` enforces that
  every `docs/*.md` mirrors its `core/protocol/*.md` canonical.

---

## Step 1. Decide the query-locally architecture

Produce an ADR that commits the framework to a tool-query context model: what the index
contains, who may read raw files and when, and where the configuration surface lives.
Resolve the `.aidd/config.json` vs `constitution.md` split explicitly, and state the
degradation path when Tree-Sitter or git is unavailable.

Acceptance:

- ADR in `docs/design/decisions/` records the chosen index format, the read-path rules, and
  the configuration-surface decision with its rejected alternative.
- Every downstream step (2-8) maps to a named section of the ADR.

Out of scope: implementing any indexer, parser, or configuration reader.

---

## Step 2. Build the dual-state index (Tree-Sitter AST + content hashes)

Implement a local indexer that walks the repo and emits a JSON dictionary of file paths,
class and function signatures, and byte spans, each paired with a git blob hash so a stale
entry is detectable without reparsing. Wire it into `build-snapshot.sh` as an additional
artifact alongside the existing prose pack.

Acceptance:

- `index.json` for this repo is under 100 KB and lists every function and class with its
  file, line span, and content hash.
- Re-running the indexer with no working-tree change reparses zero files (hash short-circuit).
- Missing Tree-Sitter grammar degrades to a path-and-hash-only entry rather than failing.

Out of scope: replacing or removing the existing prose snapshot pack.

---

## Step 3. Add just-in-time context ingestion

Add a `read_block` local command that returns exactly one symbol's source plus its
immediate type or signature dependencies, resolved through the Step 2 index, so a role
pulls a 40-line span instead of a 1,000-line file. Update the dispatch protocol so roles
are instructed to query rather than read whole files.

Acceptance:

- `read_block <file> <symbol>` returns the symbol body and its directly referenced type
  definitions, and nothing else.
- A stale index entry is detected by hash mismatch and triggers a targeted reparse of that
  file only.
- `core/protocol/dispatch.md` states the query-first read rule for every role.

Out of scope: changing which roles exist or what dimensions they review.

---

## Step 4. Feed the adversarial verifier content-addressable diffs

Stop resending changed files through the verification loop. The builder registers each
change as a commit or patch; the verifier receives the isolated `git diff` plus, on demand,
Step 3 spans for context.

Acceptance:

- The verification dispatch in `core/protocol/pr-review.md` carries a patch reference, not
  file bodies.
- A verifier given only a patch can still resolve surrounding context via `read_block`.
- Findings still cite `file:line` against the post-change tree.

Out of scope: changing the two-phase review protocol or its verdict vocabulary.

---

## Step 5. Redact test-execution logs before they reach a role

Add a local filter that reduces a raw failure log to the error type, the failing assertion,
and the `file:line`, stripping environment noise, repeated path prefixes, and duplicate
frames. Signal preservation is the hard constraint — a redactor that eats the real error is
worse than no redactor.

Acceptance:

- On a captured multi-thousand-line failure log the filter emits a structured summary and
  the reduction ratio is recorded.
- No rule can remove the error type, the failing assertion text, or the failing `file:line`;
  a regression test asserts this against fixtures.
- Unrecognized log formats pass through truncated-but-labeled, never silently emptied.

Out of scope: changing which tests run or how they are invoked.

---

## Step 6. Run natively as a git hook and a GitHub Action

Make the framework trigger itself: a `pre-commit` hook for the fast local path and a
reusable GitHub Action that runs the adversarial review on push, instead of requiring a
human to invoke a command.

Acceptance:

- `pre-commit` hook runs the fast-mode check and exits non-zero on a blocking finding.
- A reusable workflow runs the review on pull requests and posts results under the existing
  `pr_review.post_comments` opt-in.
- Hook installation is opt-in, idempotent, and reversible; CI stays green.

Out of scope: changing the gate model or making any hook auto-merge.

---

## Step 7. Sandbox test execution in ephemeral containers

Isolate agent-run test commands inside a disposable Docker or equivalent container so a
generated command cannot damage the host working tree. Falls back to the current
host-execution path, loudly, when no runtime is present.

Acceptance:

- Test runs execute in a container with the repo mounted and network off by default; the
  container is removed after the run.
- A destructive command inside the sandbox leaves the host tree byte-identical, proven by a
  test.
- No container runtime present degrades to host execution with an explicit recorded warning,
  never a silent fallback.

Out of scope: containerizing the framework's own orchestration or shipping a base image.

---

## Step 8. Model-agnostic cost tuning

Add the configuration surface chosen in Step 1 so dispatch classes route to different
models — cheap models for mechanical work, frontier models for adversarial review — with
per-model cost rates feeding the existing cost ledger.

Acceptance:

- A dispatch class to model mapping is read from configuration; an unmapped class falls back
  to a declared default rather than failing.
- Cost-ledger rows carry the model actually used and its rate.
- Provider credentials are read from the environment only, never from a committed file, and
  a test asserts no credential can be written into repo state.

Out of scope: implementing provider SDK clients or a proxy layer.

---

## Step 9. Measure the token claim

The entire pivot is a cost claim, so it must be falsifiable. Extend the existing benchmark
harness to record tokens and wall-clock for the same tasks before and after Steps 2-5.

Acceptance:

- Benchmark tasks run under both the old read-everything path and the new query path, with
  per-task token counts recorded.
- Results record defect-detection parity — a cheaper run that finds fewer real defects is a
  regression, not a win.
- The measured medians replace the derived constants in `cost-governance.md`.

Out of scope: adding new benchmark repositories.

---

## Step 10. Document the new execution model

Update the protocol canonicals and their `docs/` mirrors, the README, and the changelog to
describe the query-locally model, the hook and sandbox surfaces, and the configuration keys.

Acceptance:

- `scripts/check-refs.sh` passes with every new `core/protocol/*.md` mirrored in `docs/`.
- README and CHANGELOG describe the pivot and the new configuration keys.
