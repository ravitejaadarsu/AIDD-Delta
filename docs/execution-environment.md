# Execution Environment

Canonical: `core/protocol/execution-environment.md`.

Where and how the framework runs: whether it is safe to let an agent act,
affordable to let it think, and likely to actually run at all.

## Sandboxed execution

The threat is not malice, it is confident wrongness — `rm -rf "${BUILD_DIR}"`
with `BUILD_DIR` unset is one expansion from the user's home directory.
`core/scripts/aidd-sandbox.sh` runs agent-issued commands in a disposable
container: `--rm`, network off, repo mounted read-only unless `--writable`,
never root, memory and pids capped.

**Degradation is loud by design.** With no runtime the command still runs — on
the host, with the reason on stderr for the run's degradation record;
`AIDD_SANDBOX_REQUIRED=1` makes that a hard failure instead. A silent fallback is
the one unacceptable outcome. Sandbox-level failures exit **125**, distinct from
any test exit code.

## Model routing

Every dispatch on one frontier model is the easy default and the expensive one.
`.aidd/config.json` (seeded from `core/templates/config.json`) maps dispatch
classes to models and effort, with per-model rates feeding the cost ledger.
`core/scripts/aidd-route.sh` resolves `model`, `effort`, `rate`, `cost`, `table`,
and `audit`.

The split from `constitution.md` is the approval requirement, not the format:
constitution.md holds policy a human must approve; config.json holds routing a
script reads on every dispatch. Four rules do not bend — an unmapped class falls
back to the default rather than failing; an unpriced model records `na`, never
`0`; credentials come from the environment only (and `audit` fails the run on a
credential-shaped entry); the ledger records the model actually used, per
dispatch.

## Self-triggering

A review that needs someone to remember to ask for it stops happening under
deadline.

- **Local** — `core/scripts/aidd-install-hooks.sh` installs a `pre-commit` hook
  that is opt-in, idempotent, and reversible. An existing non-AIDD hook is
  preserved and chained, never overwritten. Escape hatches: `--no-verify` for
  one commit, `AIDD_HOOK=off` for a session. The hook stays small — credential
  audit (blocking) and staged-file index refresh (advisory) — because a slow
  hook gets bypassed, and a bypassed hook checks nothing.
- **CI** — `.github/workflows/aidd-review.yml` runs on every pull request and
  performs only the checks needing no model and no credentials, so it works on
  fork PRs. It never posts to a PR thread: automating the trigger does not
  automate the consent.

Design rationale: `docs/design/decisions/020-execution-environment.md`.
