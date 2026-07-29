# Impact Analysis

Canonical:
`core/roles/impact-analyst.md`; wired at `core/playbooks/20-inception.md` step 10.

Before a line is written, the Impact Analyst measures a change's **blast radius** through
four lenses — and confirms it after build:

- **Caller / dependency impact** — who actually calls the code being touched (cited
  `file:line`, never guessed), and the riskiest of those callers.
- **Public-contract impact** — API/CLI/schema/DB surface that changes, and whether it
  breaks existing consumers.
- **Data & migration impact** — persisted data, migrations, backfills, rollback path.
- **CI/CD & ops burden** — new build/test/deploy steps, flakiness, secrets, infra.

It emits `impact-report.md` with a LOW/MEDIUM/HIGH rating. Two things feed forward: any file
the blast radius reaches that no story owns is returned to the Epic Scoper (a
parallel-safety risk), and a HIGH rating sharpens the pre-implementation review. Run it
standalone with `/aidd:impact <change|diff>`.
