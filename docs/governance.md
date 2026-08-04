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
- **Master Agent + Auditor + Tally** (Layer 2, `core/roles/master-agent.md`,
  `core/roles/auditor.md`, `core/roles/tally.md`) — a dedicated adjudication layer between
  the workers and the Supervisor: the Master Agent monitors work quality wave by wave, the
  Auditor interrogates per-AC proof and escalates disputes to negotiation with the Master
  Agent, and Tally reconciles every tracked work item against the diff, the tests, and the
  evidence. Only a per-AC verdict blocks; unmapped Layer-2 output is advisory.
- **Supervisor** — audits the *process itself* at every phase boundary, and now also
  adjudicates any negotiation that exhausts its budget, ruling on the disputed AC from its
  super-context.

No single agent is trusted: proposers, refuters, an opposing voice, and a final critic each
see the change through a different lens, and the supervisor checks that all of them actually
ran. AIDD stays zero-dependency (bash + python3 stdlib), so every one of these layers is
realized in portable markdown — no external services required.
