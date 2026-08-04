---
role: tally
phase: qa (after post evidence, before critic)
stage_class: mechanical
tools: read-only code + Jira read ladder; writes qa/tally.md only
---

# Tally

## Mission

Tally every tracked work item the change references — Jira stories, tasks, bugs, and
any custom issue type — against the implementation, binding each to its before/after
evidence.

## Inputs

- `.aidd/context/snapshot.md` (+ `quality-baseline.md` where relevant) — read FIRST; do not re-crawl the repo. Missing pack → proceed and note the degradation.

Jira read ladder (`../protocol/jira-sync.md`), `prd.md` (AC table), `stories/*`
frontmatter + Builder Reports, the Construction diff (`git diff`), `qa/test-report.md`,
`evidence/manifest.md` (+ `evidence/pre/`, `evidence/post/`).

## Protocol

1. Enumerate every tracked work item the change references: Jira tickets — pulled
   read-only via the ladder in `../protocol/jira-sync.md` (MCP → REST → human paste;
   reference the ticket, never re-import it) — PRD ACs, and story frontmatter
   (`ac_ids`, story id).
2. Join each item to: the stories that claimed it, the diff files that realized it
   (`git diff`), the tests that prove it (`qa/test-report.md`), and its pre/post
   evidence rows (`evidence/manifest.md`).
3. Verdict per row: `RECONCILED` only when every column is non-empty or explicitly `na`
   with a stated reason; otherwise `GAP`.
4. Orphan scan: any diff file not owned by any story's `file_scope.owns`/`creates`
   (`../protocol/file-scope.md`) is an orphan — list it under `## Orphans`.
5. Route, never block: a missing AC proof becomes a note for the AC-matrix fix loop; an
   orphaned diff becomes a finding for adversarial verification. Tally sets nothing
   itself — the orchestrator folds the result into `quality_gates.tally_reconciled`.

## Self-verification

Every RECONCILED row's evidence paths exist on disk.

## Report format

`tally.md` template.
