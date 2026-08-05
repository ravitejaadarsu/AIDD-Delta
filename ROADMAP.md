# AIDD Delta Roadmap

Nothing on this page is done. Every box is unchecked, and a box gets checked only when there
is an artifact behind it — a published result, a merged PR, a case-study page.

## Near term — earning the claims (before v1.0)

The framework is specified in more depth than it is evidenced. Closing that gap outranks
every feature below it. In priority order:

### 1. Publish benchmark results

There are **no published benchmark results yet**. The harness exists so this is a matter of
running it and publishing what comes out, including if what comes out is unflattering.

- [ ] Run the full task set on Tier 1 and publish results with the run artifacts
- [ ] Run the same task set on Tier 2 (Codex CLI) and publish the wall-clock and cost delta —
      the sequential-tier penalty is currently an estimate, not a measurement
- [ ] Publish per-layer defect-catch attribution against the seeded defect corpus in
      `bench/defects/`, so the three-layer hypothesis is confirmed or refuted rather than
      asserted
- [ ] Publish token cost per rigor mode, so the cost-versus-rigor argument has a price on it
- [ ] Run the comparison arms (single-agent baseline, staged-prompting arm, skill-composition
      arm) and publish the comparison, whichever way it goes

### 2. Get external adopters

- [ ] One external team runs the pipeline end to end on their own repo
- [ ] Three external teams, on at least two distinct repo classes
- [ ] At least one adopter on a runtime other than Claude Code, to test the degradation
      contract against reality rather than against the matrix
- [ ] An external contributor merges a change to `core/`

### 3. Publish case studies

- [ ] First case study published (see `docs/case-studies/README.md` for the required
      evidence)
- [ ] At least one **negative** case study published — a run where the framework cost more
      than it returned. Its absence after several positive studies would itself be a signal
      worth distrusting
- [ ] A case study on a brownfield repo with thin existing tests, which is the hardest honest
      case

### 4. Tier 2 parity work

Every degraded cell in `docs/capability-matrix.md` is a candidate here. The goal is not
feature parity — parallelism is not portable — but closing the *enforcement* gap so that
Tier 2 prevents violations rather than only detecting them.

- [ ] A runtime-agnostic scope guard, so out-of-scope writes are blocked and not merely
      audited after the fact
- [ ] A state-write wrapper that validates before writing on every tier, removing the
      "orchestrator must remember to validate" duty
- [ ] A dispatch-log wrapper so the audit log cannot be selectively omitted off Tier 1
- [ ] Measure the real sequential-tier wall-clock multiplier per phase and put the number in
      the capability matrix, replacing "proportionally longer"

### 5. Make the honesty mechanical

- [ ] Extend `tests/claims.test.sh` as claims are added, so a new unqualified claim fails CI
      rather than surviving review
- [ ] A docs check that fails any capability sentence without a tier

## v1.1+ — deliberately deferred

v1 ends at a merge-ready PR whose CI has been watched. The following are out of scope for
v1; the architecture leaves room for each (groundwork noted), but none is built.

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

## Not planned

- Merging for you. AIDD stops at a merge-ready PR on purpose; the human merges.
- A hosted service, a dashboard backend, or anything that requires the framework to phone
  home.
- Claiming parallel execution off Claude Code. Sequential is the honest Tier 2/3 behavior and
  the degradation contract commits to saying so.
