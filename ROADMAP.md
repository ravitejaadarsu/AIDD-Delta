# AIDD Delta Roadmap

v1 ends at a merged-ready PR with green CI. The following are deliberately deferred —
the architecture leaves room for each (noted below), but they are not built in v1.

## v1.1+

- **Multi-change parallelism** — several concurrent changes with a global ownership
  registry and cross-change conflict detection. Groundwork already present: per-change
  folders own their own `state.yaml`, so state never contends across changes.
- **Post-merge canary watch** — watch CI on the default branch after merge and
  auto-draft a revert PR on breakage. Groundwork: Delivery ends with a machine-readable
  delivery report identifying the merge candidate.
- **Remote gate approvals** — approve G1/G2/G3 from phone/Slack via push notification.
  Groundwork: gates are pure state transitions in `state.yaml`; any authorized writer
  can record an approval.
- **Model routing & cost governance** — cheap models for mechanical stages, strong
  models for verify/judge stages; per-phase cost report. Groundwork: every role file
  declares its stage class (mechanical / generative / adjudicative).
- **Deployment phase** — optional post-Delivery deploy playbook (containers, cloud).
- **Non-GitHub CI providers** — GitLab CI / Azure Pipelines templates alongside the
  GitHub Actions template.
- **Automatic Jira write-back** — today the AC matrix syncs to Jira only with per-run
  approval; a standing-consent config may follow.
