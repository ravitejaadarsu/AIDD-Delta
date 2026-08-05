---
name: Bug report
about: Something in the framework behaved incorrectly during a run
title: "bug: "
labels: bug
---

<!-- A report without tier, runtime, rigor mode, and artifact paths usually cannot be acted
on — the same evidence bar the framework applies to itself. Redact freely; say what you
redacted. -->

## Environment (all required)

- **Tier**: Tier 1 (Claude Code) · Tier 2 (Codex CLI) · Tier 3 (other agent CLI / plain LLM)
- **Runtime and version**: e.g. Claude Code x.y.z, Codex CLI x.y.z
- **Model(s) used**:
- **Rigor mode**:
- **Autonomy mode**: `let-me-look` · `take-care`
- **AIDD Delta version**: (from `VERSION` or the plugin manifest)
- **OS / bash / python3 versions**:
- **Optional tools present**: Playwright · mutation tool · Atlassian MCP · ShellCheck ·
  markdownlint · none

## Artifact paths (required)

Point at the run. Paste paths and the relevant excerpts; attach a redacted archive if you can.

- **Change directory**: `.aidd/changes/<id>/`
- **Phase and step where it went wrong**:
- **State file** (`state.yaml`) — the `phase`, `phase_status`, `gates`, and quality-gate
  values at the time of failure:
- **The artifact that is wrong** (path + the wrong content):
- **`supervision/audit.log`** excerpt around the failure:
- **Relevant evidence block** (command, exit code, output) if the bug is an evidence or gate
  problem:

## What happened

## What you expected

Cite the rule you expected to hold, if you know it — a playbook step, a protocol file, or a
capability-matrix cell. "The matrix says supported and it was not" is an ideal bug report.

## Reproduction

- [ ] Reproduced on the bundled fixture (`tests/fixtures/sample-project/`) — steps in
      `docs/adoption.md`
- [ ] Only reproduces on my repo (describe the repo class: language, size, test maturity,
      brownfield/greenfield)

Steps:

1.
2.

## Self-test and reference check output

```text
$ bash tests/run.sh
(paste the final suites=/failures= line, and any FAIL lines)

$ bash scripts/check-refs.sh
(paste the output)
```

## Anything else
