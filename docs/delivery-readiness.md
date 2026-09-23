# Delivery readiness

**Tier 1 / Tier 2 / Tier 3:** identical checker when Python 3.9+ is available. Without
Python, delivery blocks until the check can run on another host. No packages or model calls
are required. The normative rules are in `core/protocol/gates.md`.

## Run

From the project root, after completing QA and recording approvals:

```bash
python3 .aidd/framework/scripts/aidd-ready.py .aidd/changes/<change-id>
python3 .aidd/framework/scripts/aidd-ready.py .aidd/changes/<change-id> --json
```

Exit 0 means the recorded state is ready; exit 1 means blockers; exit 2 means invalid input
or schema. JSON always contains `ready` and an `errors` array with `code` and `message`.
The tool reads files only. It never approves, writes state, runs artifact commands, pushes,
or merges. The Delivery playbook requires a successful run immediately before push.

## What it catches

- A missing, failed or pending quality gate, including a gate added to the state schema.
- An unsupported `na`, a skipped mandatory floor check, or a stale fast-mode exemption.
- Missing approvals, missing approvers, automatic approval where a human is required.
- Missing, modified or newly added artifacts within a gate's bound directories.
- Partial hashes, duplicate bindings, parent traversal and symlinks escaping the change directory.
- Pending or aborted cost stops, unfinished stories, supervision violations, unresolved
  adjudication and missing repeatability records.
- Malformed state and duplicate YAML keys that could otherwise hide an earlier value.

## Upgrade existing changes

Old single-artifact gate records still parse. A complete single-file G1 approval can pass
with a full hash. Multi-file gates need an `artifacts` list covering all their files.
Re-present the gate digest and obtain its disposition before recording those bindings.
A legacy incomplete approval is a blocker, not permission to approve additional artifacts.

## Limits

Readiness verifies recorded state, file coverage and hash consistency. A hash proves bytes
have not changed since the recorded approval; it does not authenticate the approver or prove
an agent ran a command. It does not inspect product-source changes, evaluate assertions,
reconcile the AC matrix semantically, or reproduce test results. Existing reviewers and
verification roles remain required. Run their checks again after product changes.

This CLI is a preflight, not a security boundary against an agent that can edit both state
and evidence or ignore the playbook. Independent CI enforcement, source-bound execution
receipts and externally authenticated approval records are future work.
