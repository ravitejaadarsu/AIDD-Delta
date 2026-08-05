# Escape Analysis

Canonical: `core/protocol/escape-analysis.md`. Summary:

Every layer in AIDD verifies forward. Nothing looked backward at a defect that got through all
of them. Escape analysis is the loop that closes: when a bug reaches production, the framework
works out **which layer should have caught it and why it did not** — and leaves behind a
regression test and one concrete amendment proposal.

A framework that only counts what it caught is marketing. This is the counter-metric.

## Running it

```text
/aidd:escape https://github.com/you/repo/issues/482
/aidd:escape "order totals wrong when a coupon and a refund land in the same second"
```

First the framework attributes the defective code to a merged AIDD change (`git log -S`,
`git blame`, the `aidd/<change-id>` branch). If no AIDD change produced it, the escape is
recorded `out-of-scope` and analysis stops — the framework is neither blamed nor credited for
code it never processed.

Then the Escape Analyst reads the change's whole artifact set and fills one table.

## The nine-row verdict table

Every row, every time — no omissions, no merges, no blanks:

`L1-review` (which dimension) · `L1-tests` (which category) · `L2-auditor` · `L2-tally` ·
`L2-debate` · `L3-supervisor` · `critic` · `e2e-mutation` · `evidence-capture`

| column | what it demands |
|---|---|
| `should_have_caught` | `yes` must name the artifact that would have carried the catch |
| `did` | `yes` is the **caught-then-dropped** case — refuted, waived, downgraded, ruled away. The more dangerous escape |
| `why_missed` | cite the blind artifact by path and say what it actually contained |
| `preventable_by` | one minimal change to a named file. "More review" is invalid by format |

The first six layer names are the same tokens the benchmark harness uses for injected defects
(`bench/harness.md`), so a benchmark miss and a field miss are counted in one language.

### "No layer could have caught this at reasonable cost"

A supported, legitimate verdict — and not a default. Claiming it requires saying what *would*
have caught the defect, what that technique costs on every change, and why that cost is not
worth paying. It is the verdict that keeps the framework from accreting a new checklist row
after every incident until nobody runs it.

## Two things always come out

1. **A regression test** that fails on the defect and passes after the fix — required under
   both verdicts. The Analyst specifies it; a Builder authors it under TDD inside the fix
   change (observed RED, then GREEN, both evidenced). A regression test never seen red proves
   nothing.
2. **A protocol amendment proposal** — diff-level, against a named file, minimal enough to
   accept or reject in one reading. It goes into the escape report and into `learnings.md`
   through the existing learning loop.

**Amendments are never applied automatically.** A human decides. A framework that rewrites its
own rules after every incident accretes unreviewed rules faster than anyone can audit them —
and the rules are the only thing making it trustworthy.

## Repeats escalate

Same defect class, same layer already recorded blind ⇒ the last amendment was insufficient or
was never applied. The framework does **not** re-propose it. It escalates to you with four
facts: the prior escape, the prior amendment, whether it was applied, and the evidence it did
not prevent recurrence.

## The two metrics

Recorded in `.aidd/escapes/register.md`, recomputed on every append:

- **escape rate** — escapes attributed to AIDD changes ÷ AIDD changes merged, over the last 20
  merged changes (tunable).
- **layer blindness** — per layer, escapes whose blind layers include it ÷ escapes analyzed.

Both always print the numerator and the denominator; a window with no analyzed escape reads
`not measured`, never `0%`. Zero measured escapes is an absence of data, not a perfect record.

Any claim about what AIDD catches has to be readable next to this register. A detection number
published without its escape rate is unfalsifiable.
