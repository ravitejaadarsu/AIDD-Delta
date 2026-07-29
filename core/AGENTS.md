<!-- AIDD:BEGIN — managed block; install.sh updates between these markers -->
# AIDD Delta

This repository uses [AIDD Delta](https://github.com/aidd-delta/AIDD-Delta) —
one intent → production-ready delivery.

## Routing rule (for any AI coding agent)

If the user's message starts with `AIDD:` or clearly requests an AIDD workflow
(build/plan/qa/deliver a change), open `.aidd/framework/playbooks/00-pipeline.md` and
follow it exactly. **Never improvise phase logic.**

| Request | Do |
|---|---|
| "AIDD: build <intent>" / "AIDD: <JIRA-KEY>" | Run `.aidd/framework/prompts/go.md` |
| "AIDD: status" | Run `prompts/status.md` |
| "AIDD: resume" | Run `prompts/resume.md` |
| "AIDD: approve" / "AIDD: revise — <notes>" | Follow `.aidd/framework/protocol/gates.md` |
| "AIDD: set mode take-care/let-me-look" | Update mode per `protocol/autonomy-modes.md` |
| "AIDD: run <document/master/inception/construction/qa/delivery>" | Run the matching `prompts/<phase>.md` |
| "AIDD: test <story/fix>" | Run `prompts/test.md` (exhaustive test-engineer team) |

## Ground rules

- State lives in `.aidd/` (YAML, schema-validated — validate after every write with
  `python3 .aidd/framework/scripts/aidd-validate.py`).
- Agents without parallel subagents execute fan-outs sequentially in the documented
  order — never skip a role.
- Evidence over assertion: commands, exit codes, and output excerpts in every report.
<!-- AIDD:END -->
