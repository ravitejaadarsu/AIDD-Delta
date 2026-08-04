# Dashboard

`bash .aidd/framework/scripts/render-dashboard.sh` regenerates `.aidd/dashboard.html`
from state (the orchestrator does this after every state write; `/aidd:dashboard` on
demand). It is a single self-contained file — open it in any browser, no server:
phase progress, gate ledger with approvers, the fourteen quality gates, stories per wave,
supervision verdicts, and recent history. Template:
`core/templates/dashboard.html`.
