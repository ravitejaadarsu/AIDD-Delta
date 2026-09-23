# Implementation report — September 24, 2026

## Outcome

Delta now has an executable evidence workflow that can be used independently of the full
agent pipeline: capture a verification command, bind it to source bytes, check every approved
requirement, detect stale proof and export a local report. New pipeline changes require that
evidence before delivery. The public repository also has a clearer pilot entry point and a
commercial validation plan. No revenue, customers or competitive benchmark wins are claimed.

## What shipped

| Enhancement | Practical benefit | Implementation |
|---|---|---|
| Source-bound execution receipts | Old passing tests stop qualifying after source edits | `core/scripts/aidd-evidence.py` |
| Bounded command execution | Timeout, interruption, failed launch and output overflow cannot become passing evidence | Capture subcommand, explicit host acknowledgment and process-group cleanup |
| Output integrity checks | Modified or truncated output invalidates a receipt | SHA-256 and byte-count verification |
| Approved requirement coverage | Omitted criteria and changed criterion text block evidence validation | G1-bound requirements plus an acceptance manifest |
| Delivery integration | New changes require successful current suite and AC evidence | receipts-v1 state contract, QA wiring and existing preflight |
| Legacy migration behavior | Old changes remain readable without pretending source freshness was verified | Explicit warning when receipts-v1 is absent |
| Setup doctor | Users can find missing setup without running project commands | `core/scripts/aidd-doctor.py` |
| Standalone evidence report | Reviewers get a shareable criterion/blocker summary | `core/scripts/aidd-report.py`, HTML and JSON, no remote assets |
| Offline first-run demo | Users can inspect the core value without an API key or agent setup | `scripts/demo-evidence.py` |
| Verification recipes | Teams can adapt existing checks across common stacks and risk areas | `docs/verification-recipes.md` |
| CI template fails closed | Unconfigured build/test/lint placeholders cannot silently produce green CI | `core/templates/ci-workflow.yml` |
| Immutable action dependencies | Official checkout, Python setup and artifact upload actions use verified release commit hashes | Repository workflows and generated CI template |
| Portable CI coverage | Minimum Python and macOS behavior get automated regression coverage | Added Linux/Python 3.9 and macOS/Python 3.13 jobs |
| Pilot intake and business plan | Clear path from repository interest to a scoped evaluation | Team guide, inquiry form and commercial strategy |

## Verification performed

The local full suite passed with strict lint enabled: **23 suites, 0 failures**, including
ShellCheck and the pinned Markdown linter. The new and extended focused tests include:

- **21 execution-evidence tests:** success/failure, source edits during and after execution,
  dirty/untracked/deleted/executable changes, output tampering, timeouts, interrupts, output
  limits, subprocess descendants, missing executables, malformed receipts, metadata omissions,
  shell-text handling, symlink escapes and approved-criterion omissions.
- **21 delivery-readiness tests:** existing approval/gate protections plus receipts-v1
  integration, valid source evidence, missing receipts and stale source rejection.
- **6 product-tool tests:** HTML escaping/CSP, missing setup, installed-tool interoperability,
  the offline demo, preserving an existing report on an overwrite attempt, and failing CI placeholders.

These are framework regression results, not proof of better AI-generated code or a full
real-customer pipeline evaluation. The first implementation commit passed all three GitHub CI jobs, including Linux/Python 3.9
and macOS/Python 3.13. Follow-up CI dependency maintenance is checked on its own pushed
commit; the Actions history is the authoritative per-commit record. Native Windows capture is unsupported;
Linux, macOS and WSL are the intended capture environments.

## Why this is commercially useful

The proposed entry point is **evidence that remains connected to the code being reviewed**.
A team can try that narrow workflow with its current agent and test runner. It gives a pilot
something concrete to measure: missed criteria, stale proof, review effort and false blockers.
It also creates a plausible foundation for later paid operational features such as managed
history, authenticated approvals and organizational policy—if buyers validate the need.

The [commercial strategy](commercial-strategy.md) proposes pricing experiments and a
30-day discovery plan. Those prices are hypotheses, not launched plans. The
[team evaluation guide](teams.md) and public inquiry form are available; no customers were
contacted, payment accounts created, license terms changed or subscriptions launched.

## Limits and risks

- Receipts are unsigned local records. An actor who controls the checker and artifacts can
  forge them. Trusted CI and authenticated approval identity remain future work.
- A passing command can contain a weak or irrelevant assertion. Semantic review and existing
  adversarial/determinism checks remain necessary.
- Fingerprints exclude root .aidd, ignored files, environment variables, dependencies and
  external systems. Endpoint hashing does not detect changes made and reverted during a run.
- External/non-file symlinks and submodules block capture. Hashing large repositories adds
  local I/O cost; no performance benchmark for large monorepos is published.
- Host execution is explicit and not a sandbox. Callers choose isolation and must avoid putting
  secrets in argv or logs. Nothing uploads raw output automatically.
- New receipt-required changes need structured ACs and may need renewed QA/G3 after delivery
  documentation edits or rebases. This intentionally exposes stale proof instead of hiding it.
- The exporter reports evidence status, not security, compliance or delivery certification.

## Best next investments

1. Run the workflow on several real repositories and publish permissioned failures as well as
   successes. Measure overhead and false blockers before optimizing.
2. Conduct the matched comparison already described in the benchmark harness. Pin tasks,
   models, configurations and budgets; include repeated runs and a verification-layer ablation.
3. Validate one paid assisted pilot before building a hosted product. Track founder delivery
   effort and whether the team continues using the workflow afterward.
4. Add trusted CI attestation and authenticated approvals only with a defined trust model.
5. Extend supported source layouts and test-output adapters according to observed customer
   needs, while preserving explicit proof scope and backwards compatibility.

## Try it

```bash
python3 core/scripts/aidd-doctor.py
python3 scripts/demo-evidence.py
```

For a real repository, follow [execution receipts](execution-receipts.md). The demo creates
and cleans up a temporary repository and makes no model or network calls.
