# Governance

AIDD Delta's precision comes from layered, independent scrutiny:

- **Independent Thinker** (`core/roles/independent-thinker.md`) — a devil's advocate that
  argues the honest case *against* the chosen architecture before any code is written, so
  the plan is stress-tested at G2, not in production.
- **Adversarial Verifier** — every CRITICAL/HIGH finding must survive a reviewer paid to
  refute it; only confirmed defects block.
- **Critic** (`core/roles/critic.md`) — a single consolidated pre-merge verdict
  (APPROVE / APPROVE WITH CONDITIONS / REJECT) synthesizing all QA evidence, gating G3 via
  `critic_approved`.
- **Master Supervisor** — audits the *process itself* at every phase boundary.

No single agent is trusted: proposers, refuters, an opposing voice, and a final critic each
see the change through a different lens, and the supervisor checks that all of them actually
ran. AIDD stays zero-dependency (bash + python3 stdlib), so every one of these layers is
realized in portable markdown — no external services required.
