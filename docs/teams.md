# Evaluate Delta with your team

Delta is an early-stage open-source project for teams that need inspectable evidence behind
AI-assisted changes. Start with a narrow evaluation: can your reviewers tell which approved
requirements were exercised, against which source, and whether that evidence is still current?

## Available today

- Local source-bound execution receipts using your existing verification commands.
- Acceptance evidence checked against the approved requirement set.
- Delivery preflight for approval freshness and unresolved state.
- Setup diagnostics and standalone HTML/JSON reports, with no hosted account or telemetry.

Try `python3 scripts/demo-evidence.py` from the repository before installing it into a product.
The demo has no model or API cost. Real agent work and external test services use your own
providers and may incur their normal costs.

## A useful pilot

Choose one repository, one owner and 5–10 representative changes. Record the baseline review
process first. For each change, measure setup friction, review time, stale/missing evidence
caught, false blockers and execution overhead. Publish only redacted artifacts you are
allowed to share. End with an explicit decision to adopt, revise or stop.

Use the repository's **Team pilot inquiry** issue form to describe a non-confidential use case
and the outcome you want to evaluate. Opening an issue does not purchase service or establish
an SLA. Availability, scope and commercial terms require a separate agreement with the owner.
Do not post proprietary code, secrets, customer data or private logs in a public issue.

## Proposed paid services

Potential offers are assisted setup, verification-workflow design, benchmark evaluation and
ongoing support. A hosted dashboard, authenticated approvals, organization policy management
and retained audit history are future product ideas. They are not shipped services or
compliance certifications. We are seeking evidence of demand before building that platform.

The open-source core remains under its existing repository license. This page does not change
license terms or make guarantees about model quality, defect prevention or revenue.
