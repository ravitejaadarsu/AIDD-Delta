# PR Review

Canonical: `core/protocol/pr-review.md`. Summary:

Reviewing a pull request **AIDD did not write** is a different job from reviewing its own
output. There is no PRD, no story, no ownership set, no TDD evidence — just a diff, a repo, a
ticket, and an author who is not this framework. So the protocol replaces provenance with two
things: ground truth taken from the commits, and adversarial verification of every finding
before anyone sees it.

Every review gates production. The output is a verdict, a funnel of findings that survived a
motivated skeptic, and a post-ready comment list that nobody posts without being asked.

## Running it

```text
/aidd:review-pr 4821
/aidd:review-pr https://dev.azure.com/acme/Phoenix/_git/phoenix-web/pullrequest/4821
/aidd:review-pr origin/main..feature/device-flags
```

## The rule that shapes everything: two phases, never a solo read

**A single-pass read may not produce a review verdict.** One reader produces two failure
classes at once — plausible-but-wrong findings, and cross-dimension misses — and neither is
fixable by reading harder. They are fixable by making a *different* agent try to break each
finding, and by giving one agent the whole feed at the end.

Five phases:

| Phase | What runs | What it produces |
|---|---|---|
| **0 — ground truth** | fetch the PR's source and target; `git merge-base <target> <source>` | the resolved BASE and HEAD SHAs, recorded as evidence |
| **1 — finders** | one agent per changed source file (+ sweeps + dimension specialists) | findings with `raised_by`, `file:line`, side, proposed severity, a concrete scenario |
| **2 — verification** | the adversarial verifier, on **every** finding, never the agent that raised it | CONFIRMED / REFUTED, with the final severity |
| **3 — cross-cutting** | one agent holding all artifacts and all verdicts | what per-file agents structurally cannot see, plus dedup |
| **4 — comment validation** | the final gate over the full feed | the post-ready comment list, and the drop list |

## Ground truth comes from the commits

The PR description is a claim about the change, usually written before the last three pushes.
It is the single most common source of confident-and-wrong findings.

- Azure DevOps: `az repos pr show --id <id>` or the `pullrequests` REST endpoint.
- GitHub: `gh pr view <pr> --json headRefName,baseRefName,headRefOid,baseRefOid,files`.
- Then, always: `git merge-base <target> <source>`. Branch tips are not the fork point —
  diffing tip against tip attributes every commit that landed on the target since the branch
  was cut to this PR's author.
- Finders work from `git diff <BASE>..<HEAD> -- <path>` and `git show <HEAD>:<path>`, so a
  claim about a function is made against the whole function, not the hunk.
- Both SHAs go in the report. Without them the review is not re-runnable and no finding's
  `file:line` is reproducible.

## Fan-out is per file, not per dimension

One agent per changed source file, scaled to the change: a component and the helper that
shipped with it are one agent; renames, formatting, E2E specs and config YAML are batched
into sweep agents; and the dimension specialists the repo configures run *in addition* —
correctness/types, framework invariants, duplication, test coverage, security, tenant
isolation. Dimension-only review misses what lives inside one file; file-only review misses
what lives between them.

Every agent reviews against the repo's own invariants (`AGENTS.md`, `CLAUDE.md`, the
constitution) **and the ticket**. Code that is correct and not what the ticket asked for is a
finding.

## Every finding is attacked by a different agent

The routing rule is mechanical, not aspirational: every finding carries `raised_by`,
verification is dispatched only as the `adversarial-verifier` role, and the dispatch plan
records `verified_by ≠ raised_by`. The verifier answers **why** it is a real problem (the code
reason) and **when** it manifests (the exact path, conditions, inputs) — and if it can do
neither, it **refutes**.

**Default to refuted when uncertain**, and **severity is set by the verifier, not the
finder**. Only CONFIRMED findings reach the report. An unproven comment on someone else's PR
costs more than a missed nit, and the reviewer's credibility is what makes the confirmed
findings land.

## The standing acceptance bar

Three verdicts, every review, `PASS | FAIL | N/A (why)`, proven against the code:

1. **Additive** — new props/params/fields are optional; nothing existing is removed or
   repurposed. Repurposing is the subtle one: a field that now means something else for some
   inputs is a breaking change wearing an additive diff.
2. **Non-breaking** — existing call sites and existing data behave identically when the
   feature is inactive. Proven by **tracing the inactive path in the code**: empty target set
   ⇒ pure pass-through, no extra DOM, no extra behavior. "The default is off" is the premise,
   not the proof.
3. **No hardcodes** — no business tokens, field ids, statuses, or entity types in framework
   code. Reading `deviceEnabled` from field metadata is CORRECT; an inline token array or
   `entityType === '…'` is a **redline**. Four parts, all reported: the redline scan, the
   allowlist file untouched, new `any`/escape hatches, and an honest assessment of whether
   the tests verify real behavior or are vacuous.

A review missing any of the three is incomplete by format.

## Trace the real consumer before flagging shared code

The rule that stops the most expensive kind of wrong comment. When a PR edits a shared util
and you suspect it flips behavior for existing metadata, **grep the actual runtime consumer
before flagging it**.

The real case it comes from: a shared `safeCondition()` changed so a condition string that
evaluated `false` now evaluates `true`. Shape-matching says every document with a `condition`
key is affected — a product-wide breaking change. The greps said otherwise: the submit-sequence
executor never imports `safeCondition`, it has its own local `resolveCondition`; the gadgets
that do import `safeCondition` get their conditions from a different metadata path; and no
shipped document routes the changed input class into it. Same key name, two engines, **zero
real consumers on the changed path**. The change was additive.

Verdicts on shared symbols are **per consumer, proven by importer greps** — never by matching
the metadata shape. The verifier asks for the trace, and an unanswered trace means REFUTED.

## Comment style

Plain, direct, natural developer tone. Not collegial, not hedged, not "humanized". Forbidden
literally, so an agent can self-check: greetings (`hey <name>`), `I feel`,
`I might be wrong here`, `can we maybe`, `just a nit but`, emojis, exclamation marks, praise
openers, `thoughts?` closers.

Required shape: one line stating the problem → the code reason → a clear closing ask
(`please do X before merge`). Every comment carries the exact file path and line number with
the **side** — right/head for added code, left/base for removed code. A comment without a
resolvable `file:line` + side is not post-ready, and a comment that fails validation is
**dropped, not softened**.

## Nothing is posted without you

The protocol emits the post-ready list and stops. Posting is an external write, so it mirrors
Jira write-back exactly: OFF by default, enabled per repo in the constitution, and still
requiring explicit human approval **in the current run** — in both autonomy modes.
`take-care` does not auto-approve a write into someone else's pull request.

## Configuration

Everything above works with zero configuration. A repo tunes it in the `pr_review:` block of
its `constitution.md`: platform, invariants files, the dimension-specialist roster, the
redline patterns and which paths count as framework code, the allowlist file, the ticket
system, and comment-style overrides.

### Worked example — a Phoenix-style setup

A large Azure DevOps monorepo with its own agent roster and its own framework allowlist:

```yaml
pr_review:
  platform: azure-devops
  invariants_files:
    - AGENTS.md
    - docs/framework-rules.md
  dimension_agents:                 # this repo's own isa-* roster replaces AIDD's six
    - isa-correctness
    - isa-metadata-invariants
    - isa-duplication
    - isa-test-quality
    - isa-security
    - isa-tenant-isolation
  framework_paths:
    - packages/framework/**
    - packages/gadgets/**
  redline_patterns:
    - "\\[\\s*(['\"][A-Za-z0-9_.-]+['\"]\\s*,\\s*){2,}['\"][A-Za-z0-9_.-]+['\"]\\s*\\]"
    - "(entityType|entity_type)\\s*[=!]==?\\s*['\"]"
  allowlist_file: .framework-allowlist.json
  ticket_system: azure-boards
  post_comments: false
  comment_style:
    address_author: true
    max_lines: 4
```

What that buys, concretely: the six `isa-*` specialists run instead of AIDD's defaults, one
dispatch each; the redline scan runs only over `packages/framework/**` and
`packages/gadgets/**`, so application code that legitimately names its own entities is not
flagged; `.framework-allowlist.json` must be untouched by the PR, and a diff that widens the
escape list while adding the code that needs it fails the third acceptance verdict; work
items come from Azure Boards, so "correct but not what the ticket asked for" is checkable;
and comments may open with a terse handle, still with no greeting.

## Tiers

Works on all three tiers. The parallel fan-out — per-file agents, sweeps, dimension
specialists, and per-finding verification running concurrently — is Tier 1; elsewhere the
identical units run sequentially in the documented order (path ascending, finding id
ascending) and the artifacts are unchanged. See the
[capability matrix](capability-matrix.md).

Canonical decision: [ADR 019](design/decisions/019-pr-review.md).
