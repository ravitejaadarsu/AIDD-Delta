# Dashboard

`bash .aidd/framework/scripts/render-dashboard.sh` regenerates `.aidd/dashboard.html`
from state (the orchestrator does this after every state write; `/aidd:dashboard` on
demand). It is a single self-contained file — open it in any browser, no server. Template:
`core/templates/dashboard.html`.

Sections, in page order:

| Section | What it shows |
|---|---|
| Phases | the pipeline, with the current phase marked |
| Rigor & cost | the rigor mode and who chose it, spend against both ceilings, the projection, cost stops, quarantined tests, and escapes analyzed (`core/protocol/cost-governance.md`, `core/protocol/determinism.md`) |
| Recent progress | the last progress lines replayed from change history (`core/protocol/progress.md`) |
| Gates | the gate ledger — status, approver, timestamp |
| Quality gates | the sixteen quality gates with each one's status **and its reason**, so an `na` earned by a rigor mode is readable rather than merely recorded (`core/protocol/gates.md`) |
| Stories | per wave, with status and attempts |
| Supervision | the per-phase Supervisor verdicts |
| History | the last state events |

Nothing on the page is computed: it renders what change state holds. A block state does not
carry reads `not recorded`, and an unmeasured projection reads `not measured` — never `0`.
