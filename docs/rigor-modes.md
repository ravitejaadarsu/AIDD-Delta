# Rigor Modes

Canonical: `core/protocol/rigor-modes.md`. Summary:

Three verification layers, exhaustive test teams, adversarial reviewers, tally, negotiation
and supervision are right for an auth bypass and excessive for a button label. The rigor
mode is how much verification a change earns — chosen by a classifier from the change's own
evidence, not by mood.

| | `fast` | `standard` (default) | `critical` |
|---|---|---|---|
| For | copy, labels, comments, docs, formatting | everything else | auth, money, data, tenancy, PII, public API, infra |
| Layer 2 (Master Agent, Auditor, Tally) | off | full cadence | full cadence |
| Interrogation / negotiation | — | 1 round / 1 exchange | 2 rounds / 2 exchanges |
| Test debate | — | design surface, 2 exchanges | 3 surfaces, pool of 6 |
| Review dimensions (post) | 2 | 5 + delta | 5 + delta |
| Test categories | 2 | 5 | 8 |
| E2E + mutation | — | yes | yes |
| Evidence | build/suite transcript | pre + post + manifest | pre + post + manifest |
| TDD, ownership, Critic, Supervisor, G3 | identical | identical | identical |

## How a mode is chosen

Mechanically, from a table — never from a vibe. Your change is `critical` if it touches any
of authn/authz, secrets/crypto, money/billing/pricing, tenant isolation, data
migration/deletion, PII, the public API contract, concurrency/locking, or infra/deploy
config; or a story is marked `risk: critical`; or the intent names a security or compliance
concern. It is `fast` only if the whole change is confined to docs, comments, copy,
formatting, or test-only files AND no acceptance criterion describes a behavior change.
Everything else is `standard`. Ambiguity always resolves upward: the classifier never
guesses `fast`.

## Escalation is one-way

If the run turns up evidence that the change is riskier than its mode — a confirmed finding
on an auth path, any security finding, a disputed AC there — the framework raises the mode,
re-runs what the new mode requires, records the escalation, and tells you at the next gate
(in `take-care` too). It never lowers the mode. Nothing you do mid-run can talk it back down.

## What never changes

Rigor reduces breadth, never honesty. In every mode: TDD evidence (a failing test before
green), disjoint file ownership, evidence blocks with real exit codes, the Supervisor's
process audit at every phase boundary, the Critic verdict, and your approval at G3 in
`let-me-look`. A step a mode skips is recorded `na` **with the mode as the reason** — the
dashboard's quality-gate table prints that reason next to the status, and the PR body's
`Rigor / autonomy` line names the mode that earned it. Never silently missing.

## Choosing it yourself

```text
/aidd:rigor critical    # pin the mode for this change
/aidd:rigor             # report the mode, who chose it, why, and any escalations
```

A pin stops the classifier from re-classifying, and is recorded. Escalation still applies.

Rigor is orthogonal to autonomy (`docs/autonomy-modes.md`): autonomy decides who approves,
rigor decides how much runs. A `take-care` change can be `critical`; a `let-me-look` change
can be `fast`.
