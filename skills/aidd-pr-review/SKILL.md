---
name: aidd-pr-review
description: AIDD external-PR review duties — ground truth from the commits, per-file finders plus the stack-detected specialist roster, adversarial verification of every finding, the review dimensions, and the no-post-without-approval rule. Use when reviewing a pull request the pipeline did not write.
---

# AIDD PR Review Skill

**This is a skill, not a command** — there is no `/aidd:aidd-pr-review`. The command is
`/aidd:review-pr`. Skills are instruction sets the orchestrator loads; before acting, load the
exact protocol the command contract binds to the invoked command
(`.aidd/framework/protocol/command-contract.md`).

Follow `.aidd/framework/protocol/pr-review.md` exactly. Ground truth is the commits, never the
PR description: fetch the PR, compute `git merge-base <target> <source>`, and record BASE/HEAD
as evidence. Fan out one finder per changed source file (sweeps for trivia and config, the
configured dimension specialists, and the stack-detected specialist roster of §15 — probed for
availability, degrading to `pr-file-reviewer` `mode: lens`, never silently). **Every** finding
goes to `adversarial-verifier` `mode: pr` — never the agent that raised it — which refutes what
it cannot trace and sets the severity. Then the cross-cutting pass (including the
unknown-unknowns duty: what SHOULD have changed and did not), then comment validation.

Every report carries the three acceptance verdicts (additive · non-breaking · no hardcodes),
the per-dimension verdicts (§16), the resolved roster, the findings funnel, and the refuted
appendix. **Nothing is posted without explicit human approval in the current run**, in both
autonomy modes.
