# PR Review Report — <PR id> · <PR title>

<!-- The deliverable a human reads. Conclusion and confirmed findings only — never raw agent
     dumps (protocol/progress.md §3). Everything else stays on disk as the audit trail. -->

## Ground truth

| Field | Value |
|---|---|
| Platform | `<azure-devops \| github \| local>` |
| Repository | `<repo>` |
| Source (head) ref | `<branch>` |
| Target (base) ref | `<branch>` |
| **BASE sha (merge-base)** | `<sha>` |
| **HEAD sha (source tip)** | `<sha>` |
| Ticket | `<KEY / work-item id / none>` |
| Rigor mode | `<fast \| standard \| critical>` |
| Files changed | `<n>` (`<n>` source · `<n>` swept) |

<!-- Both SHAs are mandatory. A report without them is invalid by format: without them the
     review is not re-runnable and no finding's file:line is reproducible
     (protocol/pr-review.md §4.3). -->

```text
$ git merge-base <target> <source>
<sha>
[exit 0] <ISO-8601 timestamp>

$ git rev-parse <source>
<sha>
[exit 0] <ISO-8601 timestamp>
```

## Specialist roster (resolved)

<!-- MANDATORY. The stack-detected roster after detection → config override → availability probe
     → rigor scaling (protocol/pr-review.md §15). Every lens whose signal fired gets a row,
     including the ones that did not run: a lens missing from this table, or a specialist listed
     here that was never dispatched, is a supervision VIOLATION (protocol/supervision.md).
     Degradation is explicit, never silent (protocol/evidence.md). -->

| Lens key | Signal that fired | Default agent | Agent dispatched | Status |
|---|---|---|---|---|
| `<lens>` | `<the path/diff signal, quoted>` | `<the shipped default specialist \| the repo's roster mapping>` | `<agent \| pr-file-reviewer mode=lens>` | `<available \| degraded → pr-file-reviewer mode=lens (agent not exposed by the runtime) \| disabled by config (reason) \| not run (rigor:<mode>)>` |

```text
$ <availability probe: the runtime's agent enumeration>
<trimmed output>
[exit <code>] <ISO-8601 timestamp>
```

<!-- The per-file agents remain the backbone in every mode: specialists are additional lenses
     over the same diff, and every specialist finding goes through the SAME adversarial
     verification, by a different agent, with the severity set by the verifier
     (protocol/pr-review.md §15 rules 1–3). -->

## Conclusion

<!-- One paragraph. What this PR does, whether it should merge, and what has to change first.
     Written last, from the confirmed findings and the acceptance bar — never from the PR
     description. -->

## Acceptance bar

<!-- All three rows, every review, proven against the code and never assumed. A report missing
     any of the three verdicts is INCOMPLETE BY FORMAT (protocol/pr-review.md §9). -->

| # | Item | Verdict | Proof (cited from the code) |
|---|---|---|---|
| 1 | **Additive** — new props/params/fields optional; nothing existing removed or repurposed | `PASS \| FAIL \| N/A (why)` | `<signature/type quoted, or the removed symbol + one broken caller>` |
| 2 | **Non-breaking** — existing call sites and existing data/forms behave identically when the feature is inactive | `PASS \| FAIL \| N/A (why)` | `<the traced inactive path: the guard/early return that makes it a pure pass-through — no extra DOM, no extra behavior>` |
| 3 | **No hardcodes** — no business tokens / field ids / statuses / entity types in framework code; behavior is metadata-driven | `PASS \| FAIL \| N/A (why)` | `<redline scan result + allowlist untouched + escape hatches + test-honesty assessment>` |

### No-hardcodes detail (all four parts reported)

| Part | Result | Evidence |
|---|---|---|
| Redline scan over new framework files | `<clean \| n hits>` | `<command + exit code>` |
| Allowlist file untouched | `<PASS \| FAIL \| N/A (no allowlist configured)>` | `<git diff --name-only excerpt>` |
| New unjustified `any` / escape hatches | `<none \| n flagged>` | `<file:line list>` |
| Do the tests verify real behavior? | `<honest assessment>` | `<per test file: real \| vacuous (string-grep, asserts on a mock, passes with the implementation deleted)>` |

<!-- The test-honesty row is an assessment, stated plainly. Proof standard: protocol/determinism.md
     — a green that gates a merge is not trusted until something shows it would go red. The
     mocked-proof defect class is catalogued at bench/defects/D-008-mocked-proof-patched-add.md. -->

```text
$ <redline scan command>
<trimmed output>
[exit <code>] <ISO-8601 timestamp>
```

## Findings funnel

<!-- raised → confirmed → refuted. The funnel is the review's own honesty record: a review that
     reports only what it confirmed has hidden its false-positive rate. -->

| Stage | Count |
|---|---|
| Raised (all finders) | `<n>` |
| Verified (adversarial, every finding) | `<n>` |
| **CONFIRMED** | `<n>` |
| **REFUTED** | `<n>` |
| Merged by dedup | `<n>` |
| Dropped at comment validation | `<n>` |
| **Post-ready comments** | `<n>` |

| Severity (set by the verifier) | CRITICAL | HIGH | MEDIUM | LOW |
|---|---|---|---|---|
| Confirmed | `<n>` | `<n>` | `<n>` | `<n>` |

## Confirmed findings

<!-- Only CONFIRMED findings appear here. Severity is the VERIFIER's value, not the finder's
     (protocol/pr-review.md §6.3) — both are shown so the drift is visible rather than argued. -->

| # | Severity (verifier) | Proposed (finder) | file:line | side | Why it is a real problem (code reason) | When it manifests (path/conditions/inputs) | raised_by → verified_by |
|---|---|---|---|---|---|---|---|

## Cross-cutting

<!-- What no per-file agent could see. One row per class actually found; `none found` is a
     legitimate value and is stated, not omitted. -->

| Class | Finding | Evidence |
|---|---|---|
| Shared-package impact on other consumers | `<...>` | `<importer greps, per consumer>` |
| Platform-only violation | `<...>` | `<...>` |
| Dead / unreachable path | `<...>` | `<the search that found no caller>` |
| Constant drift | `<...>` | `<both locations>` |
| Missing cross-boundary test | `<...>` | `<the boundary and the untested direction>` |

## Consumer traces

<!-- Every shared/exported symbol whose behavior a finding claimed to change
     (protocol/pr-review.md §10). Verdict is per consumer, proven by importer greps. -->

| Symbol | Consumer | Reachable by the changed input class? | Grep | Verdict |
|---|---|---|---|---|

## Coverage

<!-- Which agent read what — the audit surface for "was anything left unreviewed?" -->

| Unit | Mode | Paths | Artifact |
|---|---|---|---|

## Degradations

- `<none>`

## Comments

- Post-ready list: `pr-review/comments.md` — `<n>` comments
- Posting status: **not posted** — an external write requires explicit human approval in this
  run (`protocol/pr-review.md` §12, mirroring `protocol/jira-sync.md` write-back)
