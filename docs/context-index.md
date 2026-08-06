# Context Index

Canonical: `core/protocol/context-index.md`.

A role that must understand a repository has two bad options — read everything,
or guess. The index is the third: read **structure** first, then pull only the
**spans** you need. The rule it enforces is *never read a file to find a symbol*.

- **Two artifacts, both gitignored under `.aidd/context/`.** The prose pack
  (`snapshot.md`, `quality-baseline.md`, `delta.md`) says what the repo *is*;
  `index.json` says where every symbol *lives*.
- **Dual state.** Every entry carries the symbols a parser found *and* the git
  blob hash of the file they were parsed from. The hash is what makes a span
  trustworthy: a consumer compares hashes before believing a span, and a rebuild
  reparses only files whose hash moved. Structure without the hash is a cache
  with no invalidation story.
- **Tree-sitter when available, never required** (ADR 002). Absent it, a
  per-language extractor resolves spans by indentation or brace matching.
  Unknown, binary, or oversized files still get a path-and-hash entry, so
  staleness stays detectable even where structure is opaque.
- **`aidd-read-block.py` serves one symbol**, plus its signature-scoped type
  dependencies — not the file, and not the call graph. It hashes before serving
  and reparses that one file on a mismatch, so a stale span is never served.
- **The index is a reading aid, not a verification artifact.** Gates never pin
  an index hash, and no finding rests on the index alone — findings cite the
  tree, which is why `read_block` reads live bytes.
- **Verification carries a patch, not file bodies.** The verifier gets the
  isolated change and resolves context on demand, preserving both standing
  rules: a *different* agent verifies, and findings still cite `file:line`.
- **Test logs are redacted before a role reads them**, with the reduction ratio
  reported. The hard constraint runs opposite to compression: a redactor that
  eats the real error is worse than no redactor, so any line carrying an error
  type, an assertion, or a `file:line` is never dropped. Duplicates collapse
  *with a count*; an unrecognized format is truncated *and labelled*.
- **No unmeasured savings claim.** `bench/harness.md` turns the claim into a
  number, and a cheaper run that finds fewer real defects is a regression.

Commands: `core/scripts/aidd-index.py` (build, `--check`, `--stats`) and
`core/scripts/aidd-read-block.py` (`<symbol>`, `--line`, `--list`).
Design rationale: `docs/design/decisions/020-execution-environment.md`.
