# PR Review Protocol

Reviewing a pull request **the AIDD pipeline did not write**. Different job from the
in-pipeline Reviewer (`../roles/reviewer.md`), and the difference is not cosmetic: there is
no PRD, no story, no ownership set, no TDD evidence, no Builder Report to interrogate. There
is a diff, a repo, a ticket, and an author who is not this framework. Every assumption the
pipeline is allowed to make about provenance is unavailable here, so this protocol replaces
provenance with **ground truth from the source** and **adversarial verification of every
claim** before anything reaches a human or a PR thread.

Treat every review as gating production. The output is not a discussion; it is a verdict, a
funnel of findings that survived a motivated skeptic, and a post-ready comment list that
nobody posts without being asked.

## 1. What this reviews, and what it never becomes

In scope: an external PR on Azure DevOps or GitHub, or a local `<base>..<head>` ref pair.

- **Not the pipeline Reviewer.** `mode: post` judges a diff AIDD produced against artifacts
  AIDD produced. This protocol judges a diff produced elsewhere against the repo's own
  invariants and the ticket's intent, with no artifact set to lean on.
- **Not a linter.** Style that a formatter or a lint rule already owns is not a finding. If
  the repo's CI would have caught it, the review says so once and moves on.
- **Not a rewrite.** No agent in this protocol edits repository code. Every role is
  read-only over the tree plus git probes; the only writes are the review's own artifacts.
- **Not a poster.** Nothing reaches the PR thread without an explicit human approval in the
  current run (§12).

## 2. Two rules that never bend

### 2.1 Two-phase — a solo read never produces a verdict

**A single-pass read may not produce a review verdict.** Every review runs at least two
phases over the same code: a **find** phase (§5) and an independent **verify** phase (§6),
followed by the cross-cutting pass (§7) and comment validation (§8).

The reason is measured, not aesthetic. A single reader produces two failure classes at once:
plausible-but-wrong findings, which cost the author's trust and the reviewer's credibility;
and cross-dimension misses, because the reader who is tracing correctness in one file is not
simultaneously holding the shared-package consumers, the platform rules, and the constant
drift. Neither class is fixable by reading harder. They are fixable by making a **different**
agent try to break each finding, and by giving one agent the whole feed at the end.

A run that produces a report from one agent's read is **incomplete by format**: the report
has no `verified_by` column to fill, no funnel, and no acceptance-bar proof, so it fails its
own template. The orchestrator does not emit it.

### 2.2 Nothing is posted without explicit human approval

Posting is an external write. §12 is the full rule; it is stated here because it is the other
thing that never bends.

## 3. Configuration — the `pr_review:` block in `constitution.md`

Per-repo settings live in the repository's `constitution.md`
(`../templates/constitution.md` ships the block). **Every key has a default, so the
capability works with zero configuration** — a repo with no `pr_review:` block gets the
defaults below and the review runs.

```yaml
pr_review:
  platform: github                  # azure-devops | github | local
  invariants_files:                 # read by every finder before it judges
    - AGENTS.md
    - CLAUDE.md
    - .aidd/constitution.md
  dimension_agents:                 # the repo's own specialist roster, or AIDD's defaults
    - correctness-types
    - framework-invariants
    - duplication-consistency
    - test-coverage
    - security
    - tenant-boundary
  framework_paths: []               # paths that count as "framework code" for the redline scan
  redline_patterns: []              # ripgrep patterns; empty = the shipped defaults (§9.3)
  allowlist_file: null              # e.g. .framework-allowlist.json — must be untouched by the PR
  ticket_system: none               # jira | azure-boards | github-issues | none
  post_comments: false              # NEVER true by default; see §12
  comment_style:
    address_author: false           # terse surname/handle only when true; never a greeting
    max_lines: 4
```

| Key | Default when absent | What the default means |
|---|---|---|
| `platform` | `local` if no PR id is supplied, else inferred from the remote URL | `dev.azure.com`/`visualstudio.com` ⇒ `azure-devops`; `github.com` ⇒ `github` |
| `invariants_files` | the first of `AGENTS.md`, `CLAUDE.md`, `.aidd/constitution.md` that exists (all of them if several do) | finders judge against the repo's written law; none present ⇒ recorded as a degradation, and only the ticket intent and the code remain |
| `dimension_agents` | the six AIDD dimensions listed above, run as `../roles/reviewer.md` `mode: post` dispatches | a repo naming its own roster (`isa-*`, `platform-*`, anything) gets those agents instead, one dispatch each |
| `framework_paths` | every path added by the diff | the redline scan needs a target set; with none configured, new files are the target |
| `redline_patterns` | the three shipped patterns in §9.3 | inline token arrays, entity-type equality, business-status literals |
| `allowlist_file` | none | with none configured, the "allowlist untouched" check records `N/A (no allowlist configured)` — never `PASS` |
| `ticket_system` | `none` | with none, §5 step 3 reads intent from the PR title and description **only as a claim**, never as ground truth |
| `post_comments` | `false` | and `true` still requires per-run human approval (§12) |

A configured value the repo cannot satisfy (a `framework_paths` glob matching nothing, an
`allowlist_file` that does not exist) is recorded as a degradation in the report with its
reason. It is never silently dropped and never reported as a pass.

## 4. Phase 0 — ground truth from the source, never the PR description

The PR description is a **claim about** the change. It is written by the author, often before
the last three pushes, and it is the single most common source of confident-and-wrong review
findings. The review's ground truth is the commits.

### 4.1 Fetch, per platform

Azure DevOps:

```bash
# CLI
az repos pr show --id "<PR-ID>" --org "https://dev.azure.com/<org>" \
  --query '{title:title, source:sourceRefName, target:targetRefName,
            repo:repository.name, srcCommit:lastMergeSourceCommit.commitId,
            tgtCommit:lastMergeTargetCommit.commitId, workItems:workItemRefs}'

# REST equivalent (no az CLI available)
curl -sS -u ":${AZURE_DEVOPS_EXT_PAT}" \
  "https://dev.azure.com/<org>/<project>/_apis/git/repositories/<repo>/pullrequests/<PR-ID>?api-version=7.1"
curl -sS -u ":${AZURE_DEVOPS_EXT_PAT}" \
  "https://dev.azure.com/<org>/<project>/_apis/git/repositories/<repo>/pullrequests/<PR-ID>/workitems?api-version=7.1"

git fetch origin "<source-branch>" "<target-branch>"
```

GitHub:

```bash
gh pr view "<PR>" --json number,title,body,url,author,headRefName,baseRefName,headRefOid,baseRefOid,files
gh pr diff "<PR>"        # convenience read only — NOT the ground truth for any finding
git fetch origin "<baseRefName>" "<headRefName>"
```

Local:

```bash
git rev-parse "<base-ref>" "<head-ref>"
```

### 4.2 Compute the merge-base diff

`headRefOid` / `lastMergeTargetCommit` are branch tips, not the fork point. Diffing tip
against tip attributes every commit that landed on the target since the branch was cut to
this PR's author. Compute the merge base explicitly:

```bash
BASE="$(git merge-base "<target>" "<source>")"
HEAD="$(git rev-parse "<source>")"
git diff --name-status "${BASE}..${HEAD}"
git diff --stat "${BASE}..${HEAD}"
```

`git diff <BASE>..<HEAD>` with `BASE` from `git merge-base` is exactly `git diff
<target>...<source>` (three dots). Either form is acceptable; the two-step form is preferred
because it produces the SHAs the report has to record.

### 4.3 Record the SHAs as evidence

The resolved `BASE` and `HEAD` SHAs are recorded in the report header as an evidence block —
command, output, exit code, timestamp (`evidence.md`). A report without both resolved SHAs is
invalid by format: without them nobody can re-run the review, and no finding's file:line is
reproducible.

```text
$ git merge-base origin/main origin/feature/device-flags
9f2c1ab7d3e05c4418a2b0d9c6e77f1b2a4d8e30
[exit 0] 2026-08-06T11:02:14Z
```

### 4.4 The rule finders inherit

Finders verify against the **repo tree at HEAD**, never against the narrative:

- `git diff "${BASE}..${HEAD}" -- <path>` — what changed.
- `git show "${HEAD}:<path>"` — what the file actually is now, including the parts the diff
  does not show. A finding about a function's behavior that never opened the whole function
  is a guess.
- A PR-description statement is quotable as *the author's intent*, and it is a legitimate
  input to §9.1's additive check. It is never evidence that the code does what it says.

## 5. Phase 1 — fan out the finders

Fan-out is **per changed source file**, not per dimension only, and it is scaled to the
change. Dimension-only review misses everything that lives inside one file, and file-only
review misses everything that lives between them; the protocol runs both and reconciles them
in §7. The dispatch plan resolves through `dispatch.md` rows `PR review 1a/1b/1c` — the
orchestrator does not decide the shape.

### 5.1 The unit rules

1. **One agent per changed source file.** The unit key is the repo-relative path; the
   artifact is `pr-review/files/<path-slug>.md`, so the units are artifact-disjoint by
   construction and parallel dispatch is permitted (`dispatch.md` ownership rule 1).
2. **Bundle a helper with its component** — same agent — when they are one logical unit: a
   component and its `use*`/`*.helpers`/`*.utils` file introduced by the same PR, a class and
   its private companion, a handler and its validator. One logical unit, one reviewer, one
   artifact; the artifact names every path it covers.
3. **Batch into sweep agents**, never one agent each:
   - trivial/cosmetic changes — renames with no behavior change, import reordering,
     formatting, comment and copy edits;
   - E2E specs and configuration YAML/JSON — pipeline files, fixtures, test data.
   A sweep agent gets the whole bundle and one artifact (`pr-review/sweeps/<bundle>.md`).
   Sweeps still raise findings; they are batched because per-file attention buys nothing
   there, not because the files do not matter.
4. **Dimension specialists in addition**, one dispatch each, from `pr_review.dimension_agents`
   (defaults in §3): correctness/types, framework/metadata invariants,
   duplication/consistency, test coverage, security, tenant/boundary isolation. Each reads
   the whole diff for its dimension and writes `pr-review/dimensions/<dimension>.md`.
5. **Every unit is capped and ordered** by `dispatch.md`: cap per row, deterministic order
   **path ascending** for files and sweeps, dimension name ascending for specialists. Units
   beyond the cap queue; none is dropped.

### 5.2 What every finder does

Each per-file agent, in order:

1. `git diff "${BASE}..${HEAD}" -- <path>` for the change, and `git show "${HEAD}:<path>"`
   for the file as it now stands.
2. Read the repo's invariants files (`pr_review.invariants_files`) — the rules the repo wrote
   down about itself are the standard, not the reviewer's preferences.
3. Read **the ticket intent**: the Jira issue or ADO work item linked to the PR
   (`ticket_system`, and `jira-sync.md` for the pull mechanics). A change that is correct and
   not what the ticket asked for is a finding; so is a ticket requirement with no code.
4. Raise findings in the `pr-review-findings.md` template, each carrying: `raised_by` (the
   unit key), `file:line` **and side**, a proposed severity, a one-sentence claim, and a
   concrete scenario (inputs/state → wrong outcome). A finding without its concrete scenario
   is invalid by format and never reaches verification.
5. If the finding is about a shared or exported symbol, run §10's consumer trace **before**
   raising it, and attach the trace.

## 6. Phase 2 — adversarial verification of every finding

Every finding goes to the **adversarial verifier** (`../roles/adversarial-verifier.md`), the
role AIDD already ships, parameterized for PR mode. It is not duplicated here.

### 6.1 The routing rule (mechanical — no judgment)

**A finding is never verified by the agent that raised it.** The orchestrator guarantees it
by construction, not by intention:

1. Every finding row carries `raised_by: <unit-key>`, written by the finder. A finding
   without `raised_by` is rejected by format and does not enter the queue.
2. Verification units are dispatched as the **`adversarial-verifier` role only**. No role
   that raises findings — `pr-file-reviewer`, a dimension specialist,
   `pr-cross-cutting-reviewer` — is ever dispatched to verify one. Role disjointness is the
   first guarantee: the finder's dispatch is closed before the verifier's opens, and the two
   roles are different files.
3. The verifier unit key is the finding id; its artifact is
   `pr-review/verdicts/<finding-id>.md`, disjoint from every finder artifact.
4. Before dispatch the orchestrator records `finding=<id> raised_by=<unit-key>
   verified_by=<verifier-unit>` on the dispatch-plan line and asserts
   `verified_by ≠ raised_by`. Equality is unreachable given (2); a recorded plan where it is
   not is a supervision VIOLATION (`supervision.md`) and the verification re-runs.
5. **Batching above 12 findings groups by file, never by finder** — a batch may contain two
   findings from the same finder, which is permitted; a batch may never be handed to that
   finder.

### 6.2 What the verifier must answer

The verifier's artifact answers three questions, and a verdict missing any of them is
incomplete:

- **Why is this a real problem** — the code reason. Not "this looks risky": the specific
  construct, the specific value, the specific contract it breaks, quoted from `git show`.
- **When does it manifest** — the exact runtime path, conditions, and inputs. Which caller,
  which state, which config, which platform. "Under some conditions" is not an answer.
- **If it cannot reproduce or trace it, REFUTE it.** Counter-evidence attached: the guard the
  finder missed, the caller that never passes that value, the type that makes it impossible.

**Default to refuted when uncertain.** In PR mode a verdict that cannot be proven either way
is REFUTED, not PLAUSIBLE-and-advisory: an unproven comment on someone else's PR costs more
than a missed nit, and the reviewer's credibility is the thing that makes the confirmed
findings land. Only **CONFIRMED** findings reach the final report.

### 6.3 Severity is set by the verifier

The finder proposes a severity; **the verifier sets it**. The severity in the report and in
every comment is the verifier's value, because severity is a claim about impact and impact is
what the verifier just traced. A finder that raises CRITICAL and a verifier that confirms the
mechanism but traces it to a dead configuration path produces a LOW — and the report shows
both numbers, so the drift is visible rather than argued.

Any finding on a **shared or exported symbol** carries a mandatory extra verifier question:
§10's consumer trace. Unanswered ⇒ REFUTED.

## 7. Phase 3 — the cross-cutting agent

One dispatch, sequential, after every verdict is in. It holds **all** per-file artifacts, all
sweep artifacts, all dimension artifacts, and every verdict — the whole feed. Its job is
precisely what a per-file agent structurally cannot do, because a per-file agent's context is
one file:

- **Shared-package impact on other consumers** — the PR changed a util, a hook, a base class,
  a design-system component. Who else imports it, and does the change hold for them? Answered
  by grepping importers (§10), never by shape-matching.
- **Platform-only violations** — a rule that binds one platform broken by code on another: a
  mobile-only invariant violated by web code, a server-only API called from a client bundle,
  a native-only field read in a shared model.
- **Dead or unreachable paths** — a branch the diff adds that nothing can enter, a prop
  nothing passes, a flag no metadata sets, an exported symbol nobody imports.
- **Constant drift** — a value duplicated instead of imported. The same literal, enum member,
  route, key, or threshold now existing in two places, which is a defect with a delay fuse.
- **Missing cross-boundary tests** — the change spans a boundary (component → store, service
  → repository, web → shared package) and every test lands on one side of it.
- **Dedup.** Overlapping findings from different units collapse into one, keeping the
  strongest evidence and the verifier's severity, and recording the merged ids.

Its own new findings go back through §6 like any other — the cross-cutting agent does not
verify itself.

## 8. Phase 4 — comments validation (the final gate)

One dispatch, sequential, last. The comment validator holds the **full agent feed** and every
surviving finding, and validates each candidate comment on four axes:

1. **Factual accuracy** — the comment's claim matches the code at HEAD. Re-checked against
   `git show`, not against the finding text.
2. **The exact line** it should be posted on, with the side (§11). Resolvable, or the comment
   is not post-ready.
3. **No contradiction** — no other artifact in the feed says the opposite. Two agents
   disagreeing is a signal that at least one is wrong; the comment does not ship while the
   contradiction stands.
4. **Tone compliance** — the comment contract (§11), checked literally against the forbidden
   list.

**A comment that fails validation is dropped, not softened.** Rewriting a failed comment into
a hedge is how a review ends up full of "might be worth considering" — which is noise with a
confidence penalty attached. The validator emits the final post-ready list
(`../templates/pr-comments.md`) and the drop list with reasons; the drops stay in the
artifact, so nothing disappears silently.

## 9. The standing acceptance bar

**Every review states an explicit verdict on all three, proven against the code, never
assumed.** Each gets `PASS | FAIL | N/A (why)` in the report.
A review missing any of the three verdicts is **incomplete by format** — the template has the
rows, and an empty row is not a report.

### 9.1 Additive

New props, parameters, fields, columns, and config keys are **optional**; nothing existing is
removed or repurposed.

- Prove it from the signatures: the new parameter has a default or is optional in the type;
  the new field is nullable or defaulted; the new config key has a fallback.
- Repurposing is the subtle failure: an existing field that now means something else for some
  inputs is a breaking change wearing an additive diff. Check what reads the field, not what
  writes it.
- FAIL requires naming the removed or repurposed symbol and one existing caller that breaks.

### 9.2 Non-breaking

Existing call sites and existing data/forms behave **identically** when the new feature is
inactive.

- **Prove it by tracing the inactive path in the code.** The canonical proof: with an empty
  target set, the flag unset, or the metadata key absent, the new code path is a
  **pure pass-through** — no extra DOM node, no extra wrapper, no extra event handler, no
  extra query, no changed ordering, no changed timing.
- The trace is quoted in the report: the guard that short-circuits, the early return, the
  identity branch. "The default is off" is not a trace; the default being off is the
  *premise*, and the trace is what happens next.
- An extra wrapper element rendered "harmlessly" around existing content is a FAIL. It
  changes the DOM, and something — CSS, a selector, a test, a screen reader — depends on it.

### 9.3 No hardcodes

No business tokens, field ids, statuses, or entity types hardcoded in framework code.
Behavior is **metadata-driven**.

- **CORRECT:** reading a flag from field metadata — `field.deviceEnabled`,
  `meta.capabilities.includes(x)`, a value the metadata supplies. The framework asks the
  metadata what to do.
- **REDLINE:** an inline token array (`['ORDER', 'INVOICE', 'SHIPMENT']`), an
  `entityType === 'Order'` branch, a status string compared to a literal, a field id in a
  condition. The framework is deciding on behalf of the business.

The check has four parts, all four reported:

1. **Redline scan** over the new framework files (`pr_review.framework_paths`, defaulting to
   every added path), using `pr_review.redline_patterns` or these shipped defaults:

   ```bash
   rg -n --pcre2 "\[\s*(['\"][A-Za-z0-9_.-]+['\"]\s*,\s*){2,}['\"][A-Za-z0-9_.-]+['\"]\s*\]" <paths>   # inline token array
   rg -n --pcre2 "(entityType|entity_type|recordType|objectType)\s*[=!]==?\s*['\"]"          <paths>   # entity-type equality
   rg -n --pcre2 "(status|state|fieldId|field_id)\s*[=!]==?\s*['\"][A-Z0-9_]{3,}['\"]"       <paths>   # business-status literal
   ```

   No ripgrep on the host ⇒ `git grep -nE` with the same patterns, recorded as the degraded
   path. The scan's command and exit code go in the report as an evidence block; a redline
   hit is a finding like any other and goes through §6.
2. **The allowlist file is untouched** — `git diff --name-only "${BASE}..${HEAD}"` must not
   contain `pr_review.allowlist_file`. A PR that widens the framework's own escape list while
   adding the code that needs it is the exact thing the allowlist exists to prevent. No
   allowlist configured ⇒ `N/A (no allowlist configured)`.
3. **New unjustified escape hatches are flagged** — added `any`, `as unknown as`,
   `@ts-ignore`, `# type: ignore`, `eslint-disable`, `unsafe`, reflection used to dodge a
   type. Each one either carries a comment justifying it or becomes a finding.
4. **Honest assessment of whether the tests verify real behavior.** State it plainly, per
   test file the PR adds or changes:
   - a test that greps a rendered string and asserts nothing about behavior;
   - a test whose assertions are all on mocks — including the case where the unit under test
     is itself mocked, which makes the assertion compare a configured return value with
     itself (`../../bench/defects/D-008-mocked-proof-patched-add.md`, defect class
     `mocked-proof`);
   - a test that would still pass with the feature's implementation deleted.

   The proof standard is the framework's own (`determinism.md`): a green that gates a merge
   is not trusted until something shows it would go red. Where the review can cheaply run the
   test with the new code path disabled and it still passes, that transcript is the finding's
   evidence. Where it cannot, it says so — a vacuous-test claim is raised as a finding with
   its reason, not asserted as a fact.

## 10. Trace the real consumer before flagging a shared-code behavioral change

When a PR edits a shared util, hook, gadget, or exported helper and the reviewer suspects it
flips behavior for existing metadata or config, **do not flag it until the actual runtime
consumer has been grepped.** This is a numbered protocol step, not advice:

1. Identify the exact symbol whose behavior changed, and the exact input class that now
   evaluates differently.
2. `rg -n "<symbol>"` (or `git grep -n`) across the tree for **importers** — the files that
   actually call it, not the files that mention the concept.
3. For each importer, determine whether the changed input class can reach it: what does that
   call site pass, and where does that value come from?
4. Grep for **same-named keys evaluated elsewhere.** A metadata key named `condition` does not
   imply one engine reads it. Search for other evaluators of the same key —
   `resolveX`, `evaluateX`, a local function with the same job in another module.
5. Grep the **metadata/config corpus** for documents actually carrying the changed key, and
   map each one to the engine that reads it.
6. State the verdict **per consumer**, each with the grep that proves it. Zero consumers on
   the changed path ⇒ the change is additive for the shipped corpus, and it is recorded as
   additive, not as breaking.

**A "breaking change" verdict reached by matching the metadata shape, without an importer
grep, is refused by §6.** The verifier asks for the trace; unanswered means REFUTED.

### Worked example (the real case this rule comes from)

A PR changed a shared `safeCondition()` so that a condition string which previously
evaluated to `false` now evaluates to `true`. Shape-matching says: every metadata document
with a `condition` key changes behavior — a breaking change across the whole product.

The trace said otherwise:

```bash
rg -n "safeCondition" src/            # importers: GadgetRenderer, FieldVisibility only
rg -n "resolveCondition" src/         # a SEPARATE local evaluator inside SubmitSequenceRunner
rg -n '"condition"' metadata/         # every document carrying the key is a submit-sequence definition
```

The submit-sequence executor never imports `safeCondition`; it evaluates `condition` with its
own local `resolveCondition`. The gadgets that *do* import `safeCondition` receive their
conditions from a different metadata path, and **no shipped document routes the changed input
class into it**. Same key name, two engines, zero real consumers on the changed path.

Verdict: **additive**, per consumer, proven by importer greps — not breaking. Without step 4
this review posts a CRITICAL that is wrong, on someone else's PR, in front of their team.

## 11. Comment contract

Comments are read by a human who is not this framework, on their own change, in front of
their colleagues. The style is **plain, direct, natural developer tone**. Not collegial, not
hedged, not "humanized".

### 11.1 Forbidden, literally

These strings and their close variants never appear in a comment. The list is literal so an
agent can self-check mechanically before emitting:

- `hey <name>` — or any greeting: `hi`, `hello`, `hey team`, `good morning`
- `I feel` — and `I feel like`, `my feeling is`
- `I might be wrong here` — and `I could be wrong`, `correct me if I'm wrong`
- `can we maybe` — and `maybe we could`, `would it be possible to maybe`
- `just a nit but` — and `just a small nit`, `nitpick but`
- emojis — any of them, including the approving ones
- exclamation marks — `!` does not appear in a comment
- `great work` / `nice job` / `thanks for this` and every other opener that delays the point
- `thoughts?` / `wdyt?` as a closer — the comment states an ask, it does not solicit a vibe

Hedging is the failure these prevent. A hedged comment on a real defect gets deferred; a
direct comment on a real defect gets fixed.

### 11.2 Required shape

Three parts, in this order, and nothing else:

1. **One line stating the problem.** What is wrong, in the code's own vocabulary.
2. **The code reason.** Why it is wrong — the mechanism, the input, the caller, the
   invariant. One or two sentences.
3. **A clear closing ask.** `please <do X> before merge` — or `before this ships`, or
   `please confirm <Y>` when the ask is information. The ask is imperative and specific.

Addressing the author by name is **optional and terse** — a surname or handle at the start of
the problem line, never a chatty greeting, and only when `comment_style.address_author` is
true. Default is no name at all.

### 11.3 Every comment carries file, line, and side

A comment without a resolvable `file:line` **and side** is **not post-ready** and is dropped
by §8.

| Code being commented on | Side | Line to use | GitHub | Azure DevOps |
|---|---|---|---|---|
| Added or modified (present at HEAD) | **right** | the line number in the file at HEAD | `--side RIGHT` | `rightFileStart.line` |
| Removed (present only at BASE) | **left** | the line number in the file at BASE | `--side LEFT` | `leftFileStart.line` |

Three good/bad example pairs ship with `../templates/pr-comments.md`, which is the artifact
the validator emits and the human reads.

## 12. Posting — an external write, default OFF

The protocol **emits the post-ready list and stops.** It does not post.

This mirrors Jira write-back exactly (`jira-sync.md` § Write-back): OFF by default, requires
the repo's `constitution.md` to enable it (`pr_review.post_comments: true`) **and** explicit
human approval in the current run, because it is an external side effect. The rule holds in
**both autonomy modes** (`autonomy-modes.md`) — `take-care` does not auto-approve a write into
someone else's pull request, and there is no configuration that makes it do so.

The sequence, in full:

1. The comment validator writes `pr-review/comments.md`, marked `status: not posted`.
2. The orchestrator asks, once, naming the count and the file path. The ask is a gate prompt
   under `progress.md` §5 — five lines, no prose beyond it.
3. Only an explicit approval **in that run** permits posting. Silence is not approval, a
   prior run's approval is not approval, and `post_comments: true` alone is not approval.
4. On approval, comments post via the platform CLI (`gh pr comment` / `gh api` for line
   comments; `az repos pr` / the ADO threads REST endpoint), one per comment, each with its
   file, line, and side; the artifact records the posted ids and flips to `status: posted`.
5. On refusal or silence the artifact stands as the deliverable and the run ends. Nothing is
   posted, and the report says so.

## 13. Budgets per rigor mode

A PR review inherits a rigor mode exactly as any change does (`rigor-modes.md`). The
classified surface is the merge-base diff's path set — `git diff --name-only
"${BASE}..${HEAD}"` — matched against the same trigger tables, and the same one-way escalation
applies: a CONFIRMED finding on a `critical`-trigger path raises the mode, which re-opens the
dimension roster for the dimensions the lower mode skipped.

| Surface | `fast` | `standard` (default) | `critical` |
|---|---|---|---|
| Per-file finders | one per changed source file | one per changed source file | one per changed source file |
| Sweep bundles | 1 (cosmetic and config merged) | 2 (cosmetic · config/E2E) | 2 (cosmetic · config/E2E) |
| Dimension specialists | 2 — `correctness-types`, `framework-invariants` | all 6 (or the repo's full roster) | all 6 (or the repo's full roster) |
| Adversarial verification | **every finding** | **every finding** | **every finding** |
| Consumer trace (§10) | required on every shared-symbol finding | required | required |
| Cross-cutting agent | 1 | 1 | 1 |
| Comment validator | 1 | 1 | 1 |
| Acceptance bar (§9) | all three verdicts | all three verdicts | all three verdicts |
| Redline scan + vacuous-test assessment | required | required | required |

The mode reduces **breadth** — how many specialists read the diff, how finely the trivia is
split. It never reduces the floor: the two-phase rule, verification of every finding, the
consumer trace, the three acceptance verdicts, and the no-post rule are identical in `fast`
and in `critical`. A mode that would drop one of them is a bug, not a mode.

## 14. What the human sees

**Conclusion and confirmed findings only.** Never raw agent dumps.

- The running output is `progress.md` §1 progress lines — one per completed phase, with the
  artifact path as the evidence pointer. `<phase>` carries the literal `pr-review` and
  `<total>` is 5 (phases 0–4).
- The deliverable is `pr-review/report.md` (`../templates/pr-review-report.md`): the verdict,
  the resolved BASE/HEAD SHAs, the three acceptance verdicts, the findings funnel
  raised → confirmed → refuted, and the confirmed findings with the verifier's why/when.
- The post-ready comment list is a separate artifact, and posting it is §12.
- Everything else — per-file artifacts, sweeps, dimension reports, every verdict including
  the refutations — stays on disk. It is the audit trail; it is not the message.

```text
[pr-review 3/5] 14 findings verified, 5 confirmed · .aidd/pr-reviews/PR-4821/report.md · gates: 0/0 · rigor: standard · next: cross-cutting pass
```
