# Pull Request

<!-- The checklist below is the actual review bar, not a formality. Leave a box unchecked
only with a one-line reason next to it; an unexplained unchecked box means the PR is not
ready to review. -->

## What and why

One paragraph. What changes, and which problem it solves. Link the issue if there is one.

## Claim class

If this PR adds or changes a claim in the docs, say which kind it is
(see `README.md`):

- [ ] **designed** — specified in a protocol file or ADR, and the link is in the docs
- [ ] **measured** — backed by a run whose artifacts are linked here
- [ ] **planned** — on `ROADMAP.md`, and the docs say so
- [ ] no claims added or changed

No unqualified absolute claims. `tests/claims.test.sh` enforces the deny-list.

## Checklist

- [ ] **Suite green.** `bash tests/run.sh` ends in `failures=0` — paste the final line below
- [ ] **References intact.** `bash scripts/check-refs.sh` prints `refs OK`
- [ ] **Linters ran, pinned.** ShellCheck and markdownlint both ran (locally:
      `AIDD_STRICT_LINT=1 bash tests/run.sh`); no linter version was unpinned
- [ ] **New test.** There is a test that fails without this change — or a one-line reason why
      the change is untestable
- [ ] **Capability matrix.** Any new or changed capability has a row in
      `docs/capability-matrix.md` with a filled cell for **every** tier (supported /
      degraded-how / unsupported) — or this PR adds no capability
- [ ] **ADR.** A design change (state protocol, gate semantics, installer behavior,
      verification topology, tier definitions, the blocking economy) has an ADR in
      `docs/design/decisions/` — or this PR makes no design change
- [ ] **Docs updated.** The mirror page under `docs/` reflects any user-observable behavior
      change, and every capability sentence names its tier
- [ ] **`core/` is still the only source of truth.** No phase logic, gate rule, or protocol
      text was added outside `core/`; plugin wrappers still only point at vendored copies
- [ ] **Fixtures and schemas.** A changed template or schema has updated `tests/fixtures/`
- [ ] **Version.** Bumped via `scripts/bump-version.sh` if this release-bumps — or not a
      release

## Verification output

```text
$ bash tests/run.sh
(paste the final suites=/failures= line)

$ bash scripts/check-refs.sh
(paste the output)
```

## Tier impact

Which tiers does this change behavior on? If it is Tier 1 only, state the degradation path
for Tiers 2 and 3 — that path belongs in the capability matrix, not only in this PR.

## Risk and rollback

What breaks if this is wrong, and how a user recovers.
