# Jira Integration

Canonical: `core/protocol/jira-sync.md`. Optional — AIDD never hard-depends on Jira.

- **Pull**: `/aidd:go "PROJ-123"` imports summary/description/ACs — via Atlassian MCP if
  connected, else Jira REST (`JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN`), else it
  asks you to paste the ticket.
- **Traceability**: imported ACs keep stable ids threaded PRD → stories → tests →
  `ac-matrix.md`, which proves each AC with executed test evidence.
- **Write-back** (posting the matrix / transitioning the ticket): off by default;
  requires enabling in `constitution.md` AND a per-run approval — it is an external side
  effect in both autonomy modes.
