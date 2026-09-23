# ADR 021 — Portable delivery readiness

**Decision.** Add a read-only, zero-dependency Python preflight immediately before delivery
push. Expand approval records with an array of full SHA-256 file bindings, covering every
file in each gate's artifact groups. Validate delivery semantics beyond schema shape:
quality gates, permitted exemptions, approval disposition and freshness, and unresolved
execution state. Reject duplicate YAML keys instead of retaining the last value.

**Why.** The prior schema accepted unfinished states intentionally, while gate records
could bind only one artifact despite G2/G3 covering many. Schema-valid is not delivery-ready.
Agent interpretation alone cannot reliably catch every omitted gate or stale file. A shared
CLI adds deterministic checks without another review agent or a host-specific runtime.

**Consequence.** Existing multi-file approvals require renewed disposition with complete
bindings. Python 3.9+ is required on every tier before push; unavailable execution blocks.
The checker costs local file reads and hashing, and does not prove semantic correctness,
command execution or approver identity. Verification roles remain necessary. Future changes
must test blockers through the CLI and preserve the separation between shape validation,
readiness checking and real-world evidence.
