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

## The strongest reviewer for the stack in front of it

A generic reviewer reads a Rust diff the way it reads a Python diff. So the review resolves a
**specialist roster** mechanically from the changed paths and manifests — TypeScript, React,
Vue, Python, Django, FastAPI, Go, Rust, Java, Kotlin, Swift, C++, C#, PHP, F#, Flutter, SQL and
migrations — plus language-independent lenses that fire on diff signals: security (auth,
secrets, input handling, network surface), silent failures, type design, test quality, comment
rot, accessibility, performance, ML and healthcare. A duplication sweep runs advisory-only.

Three rules keep it honest (`core/protocol/pr-review.md` §15):

- **The per-file agent stays the backbone.** Specialists are additional lenses over the same
  diff, never a replacement — the per-file count does not move in any rigor mode.
- **A specialist's finding is not privileged.** It goes through the same adversarial
  verification, by a different agent, and the verifier sets the severity.
- **Availability is probed, not assumed.** A specialist the runtime does not expose degrades to
  AIDD's own `pr-file-reviewer` in `mode: lens`, and the report's roster table says so. A
  missing agent never fails a review and never silently disappears from one.

How many specialists run scales with rigor: `fast` fields none beyond the per-file pass unless
the diff touches a redline path; `standard` fields the stack's primary reviewer plus security
when triggered and test quality; `critical` fields the full triggered set. A repo replaces any
lens with its own agent — or disables it — through `pr_review.roster`.

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

## The twelve dimensions a world-class review covers

The fan-out says who reads; the dimensions say what they look for, each with one mechanical
trigger and one evidence standard (`core/protocol/pr-review.md` §16):

| # | Dimension | The question |
|---|---|---|
| 1 | Diff-coverage | are the **changed lines** exercised by a test that would fail without them? Not project-wide coverage — and a test asserting on a mock proves nothing |
| 2 | Contract / compat | public API, exported types, schema, wire format, events: additive or breaking, per consumer, with the semver implication stated |
| 3 | Failure-mode analysis | null/empty/oversized input, timeout, partial failure, retry, concurrency — what breaks in production at 3am |
| 4 | Rollback & migration safety | reversible? down-path tested? data loss? idempotent backfill? does new code require new schema or tolerate both? |
| 5 | Feature-flag / kill-switch | is there an off switch, and does OFF equal today's behavior? |
| 6 | Observability | can a responder act on the new failure path, or is it a swallowed catch? |
| 7 | Dependency & supply-chain delta | why this dependency, its license, its transitive weight, its CVEs — and would the stdlib do? |
| 8 | Secrets & sensitive data | credentials, tokens, PII in code, logs, fixtures, snapshots (always on) |
| 9 | Performance on hot paths | N+1, unbounded work in a request path, sync work in a render path, a new query with no index |
| 10 | Concurrency & idempotency | shared mutable state, lock ordering, retry-safety of new writes |
| 11 | Dead code & constant drift | a branch nothing enters, a symbol nobody imports, a value duplicated instead of imported |
| 12 | **Unknown-unknowns** | **what should have changed and did not** — the missing test, down-path, flag, doc, telemetry, the sibling call site nobody updated, the second implementation left stale |

Mode sets the baseline set — `fast` runs three, `standard` eight, `critical` all twelve — and **a
fired trigger always adds its dimension in every mode**, so a `fast` diff that touches a migration
still gets rollback safety. Every fired dimension gets a verdict row in the report; a fired
trigger with no row is incomplete by format.

Dimension 12 is a **mandatory cross-cutting duty with its own dispatch and its own report
section**, in every rigor mode. It is the highest-value question a reviewer asks and the one a
diff-shaped review structurally never asks — and every item is answered `present` / `missing` /
`n/a` **with the search that proves it**. A "missing test" claim without the search that came back
empty is invalid by format.

## How the review holds itself to the same standard

- **The funnel is published per lens**, not just in total: raised → confirmed → refuted with a
  confirm rate for every finder. An agent that raised nine findings and had nine refuted is noise
  wearing the costume of thoroughness, and a totals-only funnel hides it.
- **Every finding carries a concrete failure scenario** (inputs/state → wrong outcome), the same
  standard the pipeline's own findings template holds. Without one it is invalid by format and the
  finder drops it rather than passing it on.
- **No style findings the repo's linter already owns.** Mechanical: if the repo ships a config
  enabling that rule, the finding is dropped as `duplicate-of-linter`, citing the config and the
  rule id. Flagging what CI enforces spends the author's attention for nothing.
- **Confidence (`proven` / `traced`) and blast radius** on every surviving finding, set by the
  verifier — so the confirmed list sorts into the order the author should fix in.
- **Refuted findings ship in an appendix** with the refutation reason. The author learns what was
  considered and dismissed, and the finders stay honest.

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
  roster:                           # this repo's stack specialists replace the shipped defaults
    typescript: isa-typescript-review
    react: isa-react-review
    database: isa-data-platform
    security: isa-appsec
    a11y: null                      # disabled: accessibility is gated by the design system's CI
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

What that buys, concretely: the six `isa-*` dimension specialists run instead of AIDD's
defaults, one dispatch each; the five mapped roster keys route the stack lenses to this repo's
own agents while every unmapped key (`python`, `go`, `silent-failure`, `test-quality`, …) keeps
its shipped default, and `a11y: null` is recorded as `disabled by config` in the report's
roster table rather than reported as clean; a mapped agent the runtime does not expose degrades
to `pr-file-reviewer` `mode: lens` with the reason published; the redline scan runs only over
`packages/framework/**` and
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
