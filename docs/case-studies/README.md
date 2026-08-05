# Case Studies

**There are none yet.** No external team has run AIDD Delta end to end and reported back, so
this directory is empty on purpose rather than curated. That is the single biggest gap in the
project, and one honest write-up of one real run closes more of it than any feature would.

If you have run the pipeline on a real repository, submit one:
[TEMPLATE.md](TEMPLATE.md) is the exact form, and
[`../../.github/ISSUE_TEMPLATE/case_study.md`](../../.github/ISSUE_TEMPLATE/case_study.md)
opens the submission.

## The two rules

1. **Unverifiable submissions are not published.** A case study is a claim about a run. If
   the artifact paths, the PR link, and the per-layer defect counts are not there — or are
   there but do not add up — it stays an issue and does not become a page here. This is not
   gatekeeping for its own sake: the whole framework rejects claims without evidence, and it
   would be incoherent for its own case studies to be the exception.
2. **Negative results are welcome and published.** "We ran it, it cost more than it was
   worth on this class of change" is a publishable finding, and a more useful one than
   another success story. So is "layer 2 flagged nothing our normal review would have
   missed", "the fix loop churned", or "we abandoned the run at G2". Nothing is edited to
   look better; a submission that reports a bad outcome is published with the same
   prominence as one that reports a good one, and it earns the same credit.

## What a case study must carry

Every field below is required. The template lays them out in order; this list is the *why*.

| Evidence | Why it is required |
|---|---|
| **Repo class** — language, size, age, test maturity, brownfield or greenfield | A result on a 2k-line greenfield service says almost nothing about a 400k-line legacy monolith. Without this the number is unusable |
| **Task class** — bug fix, feature, refactor, migration, auth/payments change | Rigor cost is task-dependent by design; a copy tweak and an auth change are not comparable runs |
| **Rigor mode** — which mode the change ran in | The mode sets the dispatch budget, so it sets the cost. A cost figure without a mode is meaningless |
| **Runtime and tier** — Claude Code / Codex CLI / other, and models used | Tier determines parallelism and enforcement automation, so it determines wall clock and how much was hook-enforced versus discipline-enforced |
| **Run duration** — wall clock, and where it was spent by phase if you have it | The honest cost side of the ledger, and the number sequential tiers are expected to be worse at |
| **Token cost** — total, and by phase if your runtime reports it | The other half of the cost side. A rigor claim without a price is half an argument |
| **Defects caught by layer** — Layer 1 / Layer 2 / Layer 3, with one line each on what the defect was | The core hypothesis is that layers 2 and 3 catch things layer 1 misses. Only per-layer attribution can support or refute it |
| **Defects the framework missed** — anything that got through and was found later | The number that decides whether any of this was worth it. Omitting it makes the study unpublishable |
| **What shipped** — merged or not, and what you changed by hand afterwards | The difference between "produced a PR" and "produced a PR a human accepted" |
| **What the framework got wrong** — bad findings, wasted loops, misjudged architecture, annoying friction | Required, not optional. A study with an empty section here reads as marketing and is sent back |
| **Links** — the PR (or a redacted diff summary) and the run's artifact directory | The verifiability requirement. Redaction is fine; absence is not |

Secrets, customer data, and proprietary source must be redacted before submission. Redacted
excerpts are acceptable evidence as long as the structure and counts survive — say what you
removed.

## What happens to a submission

1. You open a case-study issue with the template filled in.
2. The claims are checked against the linked artifacts. Gaps come back as questions.
3. If it checks out, it is published here as `NNN-<slug>.md`, verbatim in substance, with
   your attribution as you specify it (including anonymous).
4. If it cannot be verified, the issue stays open with what is missing, and nothing is
   published. No submission is quietly rewritten into something it did not say.

Related: [adoption.md](../adoption.md) for the first run,
[benchmarks.md](../benchmarks.md) for the harness a comparative claim needs.
