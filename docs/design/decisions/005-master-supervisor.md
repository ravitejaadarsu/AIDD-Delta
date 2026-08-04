# ADR 005 — A Master Supervisor audits the process itself

**Decision.** An independent role audits every phase boundary against the playbook's
compliance checklist, from a hook-fed dispatch log. Violations block phase advance; the
final session report ships in the PR body.
**Why.** Multi-agent pipelines fail silently by skipping steps, not only by writing bad
code. Product QA cannot catch process drift; a dedicated auditor of the orchestrator can.
**Consequence.** Every dispatch is logged (session-log hook on Claude Code; protocol duty
elsewhere); phase exit costs one extra adjudicative dispatch.

Amendment (2026-08-04): the role was renamed to "Supervisor" in v0.3.0; see ADR 006.
