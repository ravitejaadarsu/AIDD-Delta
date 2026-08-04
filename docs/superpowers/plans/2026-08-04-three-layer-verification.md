# Three-Layer Verification Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement AIDD-Delta v0.3.0: snapshot context system, Layer-2 Master Agent + Auditor + Tally agents with interrogation/negotiation protocols, Supervisor rename + super-context, Reviewer `mode=delta`, and the continuous test-debate protocol with Playwright MCP.

**Architecture:** Everything follows the repo's three-file role pattern (canonical `core/roles/<role>.md` + thin `agents/aidd-<role>.md` wrapper pointing at the vendored `.aidd/framework/roles/<role>.md` path + templates in `core/templates/`). Artifacts are the only inter-agent channel; all new loops are budget-bounded; new gates plug into the existing `quality_gates` enum pattern. Spec: `docs/superpowers/specs/2026-08-04-three-layer-verification-design.md` (read it before any task).

**Tech Stack:** Markdown role/protocol/template files, bash + python3-stdlib scripts (ADR 002 zero-dep rule), JSON Schema, bash test suites under `tests/*.test.sh` run by `tests/run.sh`.

## Global Constraints

- Zero hard dependencies: bash + python3 stdlib only (ADR 002). shellcheck -S warning must pass on all `.sh` files.
- Artifacts are the only inter-agent channel — no live agent messaging anywhere.
- Every loop has a hard budget: interrogation max 2 rounds; negotiation max 2 exchanges per AC; debate 2+2+2 exchanges (shared cap 6, no rollover).
- Verdict vocabularies (exact strings): Auditor per-AC `PROVEN | DISPUTED`; Supervisor adjudication `PROVEN | DEFECT | UNRESOLVABLE`; Supervisor phase verdict `COMPLIANT | VIOLATIONS`; Tally row verdict `RECONCILED | GAP`.
- New quality gates (exact keys): `auditor_approved`, `debate_complete`, `tally_reconciled` — enum `["pending","passed","failed","na"]`, mode-independent.
- Per-change audit artifacts live under `.aidd/changes/<id>/audit/` (`monitoring/`, `interrogation/`, `debate/`, `negotiation-log.md`). Snapshot pack lives at `.aidd/context/` (gitignored, never committed).
- Role file body sections, always in this order: `## Mission`, `## Inputs`, `## Protocol` (numbered), `## Self-verification`, `## Report format`. Frontmatter keys: `role`, `phase`, `stage_class`, `tools`.
- Agent wrappers reference `.aidd/framework/...` paths (vendored), never `core/...`.
- Run `bash tests/run.sh` before every commit; suite must stay green (110+ checks). `bash scripts/check-refs.sh` must pass after any file rename or new cross-reference.
- Commits: conventional style (`feat:`, `docs:`, `test:`, `refactor:`), one per task, ending with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

## Stage 1 — Snapshot context system

### Task 1: build-snapshot.sh script + test suite

**Files:**
- Create: `core/scripts/build-snapshot.sh`
- Create: `tests/snapshot.test.sh`

**Interfaces:**
- Produces: `bash core/scripts/build-snapshot.sh [tag]` → writes `.aidd/context/{snapshot.md,quality-baseline.md,delta.md}` + copies pack into `.aidd/context/history/<UTC-stamp>-<tag>/`; stores last-built commit in `.aidd/context/.last-ref`. Exit 0 on success, 1 outside a git repo. Later tasks reference the vendored path `.aidd/framework/scripts/build-snapshot.sh`.

- [ ] **Step 1: Write the failing test**

Create `tests/snapshot.test.sh` (pattern-match `tests/schemas.test.sh`: `set -uo pipefail`, `cd "$(dirname "$0")/.."`, `fail=0`, exit `$fail`):

```bash
#!/usr/bin/env bash
# Snapshot builder contract tests, run against the sample-project fixture.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# Fixture repo: copy sample project into a fresh git repo
cp -R tests/fixtures/sample-project/. "${TMP}/"
git -C "${TMP}" init -q && git -C "${TMP}" add -A
git -C "${TMP}" -c user.email=t@t -c user.name=t commit -qm init

check() { # desc, condition-exit-code
  if [ "$2" -ne 0 ]; then echo "FAIL: $1"; fail=1; fi
}

# 1. Builds all four artifacts
( cd "${TMP}" && bash "${ROOT}/core/scripts/build-snapshot.sh" post-wave-1 >/dev/null )
[ -f "${TMP}/.aidd/context/snapshot.md" ];          check "snapshot.md created" $?
[ -f "${TMP}/.aidd/context/quality-baseline.md" ];  check "quality-baseline.md created" $?
[ -f "${TMP}/.aidd/context/delta.md" ];             check "delta.md created" $?
ls "${TMP}/.aidd/context/history/" | grep -q -- "-post-wave-1$"; check "history dir tagged" $?

# 2. Idempotent: second run succeeds and history accumulates
( cd "${TMP}" && bash "${ROOT}/core/scripts/build-snapshot.sh" post-wave-2 >/dev/null )
[ "$(ls "${TMP}/.aidd/context/history/" | wc -l)" -ge 2 ]; check "history accumulates" $?

# 3. delta.md references changes since previous snapshot
grep -q "## Delta" "${TMP}/.aidd/context/delta.md"; check "delta section present" $?

# 4. Refuses to run outside a git repo
NOGIT="$(mktemp -d)"
( cd "${NOGIT}" && bash "${ROOT}/core/scripts/build-snapshot.sh" x >/dev/null 2>&1 )
[ $? -ne 0 ]; check "non-git repo rejected" $?
rm -rf "${NOGIT}"

# 5. quality-baseline rows carry evidence commands (evidence protocol)
grep -q '\$' "${TMP}/.aidd/context/quality-baseline.md"; check "baseline shows commands" $?

exit "${fail}"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/snapshot.test.sh`
Expected: FAIL lines (script does not exist yet), exit 1.

- [ ] **Step 3: Write the script**

Create `core/scripts/build-snapshot.sh`:

```bash
#!/usr/bin/env bash
# Build the AIDD repo-level snapshot context pack under .aidd/context/.
# Usage: build-snapshot.sh [tag]      e.g. post-wave-1, pre-inception (default: manual)
# Zero hard dependencies (ADR 002): bash + git + python3 stdlib optional.
# Output is gitignored and NEVER committed; rebuilt each iteration and on resume.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "build-snapshot: not a git repo" >&2; exit 1; }
CTX="${ROOT}/.aidd/context"
TAG="${1:-manual}"
STAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
mkdir -p "${CTX}"

ev() { # evidence block: command + trimmed output + exit code (evidence protocol)
  echo '```'
  echo "\$ $*"
  out="$("$@" 2>&1 | head -40)"; code=$?
  echo "${out}"
  echo "[exit ${code}] ${STAMP}"
  echo '```'
}

# ── snapshot.md: repo tree + module map + entry points ──────────────────────
{
  echo "# Repo snapshot — ${STAMP} (${TAG})"
  echo
  echo "## Tracked tree (top 500)"
  echo '```'
  git -C "${ROOT}" ls-files | head -500
  echo '```'
  echo
  echo "## Module map (files per extension)"
  echo '```'
  git -C "${ROOT}" ls-files | awk -F. 'NF>1 {print $NF}' | sort | uniq -c | sort -rn | head -20
  echo '```'
  echo
  echo "## Entry points / manifests"
  echo '```'
  git -C "${ROOT}" ls-files | grep -Ei '(^|/)((package|pyproject|cargo|go|pom)\.(json|toml|mod|xml)|makefile|justfile|main\.[a-z]+|index\.[a-z]+|setup\.(py|cfg))$' || echo "(none detected)"
  echo '```'
} > "${CTX}/snapshot.md"

# ── quality-baseline.md: measured sigmas, every number with its command ─────
{
  echo "# Quality baseline — ${STAMP} (${TAG})"
  echo
  echo "## Test files"
  ev bash -c "git -C '${ROOT}' ls-files | grep -Eic '(^|/)(tests?|spec)/|[._-](test|spec)\.' || true"
  echo "## Repo size (tracked files)"
  ev bash -c "git -C '${ROOT}' ls-files | wc -l"
  echo "## Largest files (complexity hotspots proxy)"
  ev bash -c "git -C '${ROOT}' ls-files -z | xargs -0 wc -l 2>/dev/null | sort -rn | head -11 | tail -10"
  echo "## TODO/FIXME markers"
  ev bash -c "git -C '${ROOT}' grep -nE 'TODO|FIXME' -- . 2>/dev/null | wc -l"
  echo
  echo "Project-specific sigmas (coverage %, lint, mutation) come from the canonical"
  echo "commands in architecture.md when a change is active; absent that, rows above"
  echo "are the baseline and missing sigmas are explicit \`na\` (degradation is explicit)."
} > "${CTX}/quality-baseline.md"

# ── delta.md: churn since previous snapshot ─────────────────────────────────
LAST_REF=""
[ -f "${CTX}/.last-ref" ] && LAST_REF="$(cat "${CTX}/.last-ref")"
{
  echo "# Context delta — ${STAMP} (${TAG})"
  echo
  echo "## Delta since previous snapshot (${LAST_REF:-none})"
  echo '```'
  if [ -n "${LAST_REF}" ] && git -C "${ROOT}" rev-parse -q --verify "${LAST_REF}" >/dev/null; then
    git -C "${ROOT}" diff --stat "${LAST_REF}" HEAD | tail -30
  else
    echo "(first snapshot — no previous ref)"
  fi
  echo '```'
  echo
  echo "## Working tree"
  echo '```'
  git -C "${ROOT}" status --short | head -30
  [ -z "$(git -C "${ROOT}" status --short)" ] && echo "(clean)"
  echo '```'
} > "${CTX}/delta.md"
git -C "${ROOT}" rev-parse HEAD > "${CTX}/.last-ref"

# ── history trail ───────────────────────────────────────────────────────────
HIST="${CTX}/history/${STAMP}-${TAG}"
mkdir -p "${HIST}"
cp "${CTX}/snapshot.md" "${CTX}/quality-baseline.md" "${CTX}/delta.md" "${HIST}/"

echo "snapshot pack built: ${CTX} (history: ${HIST})"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/snapshot.test.sh && echo OK`
Expected: `OK` (exit 0). Also run `shellcheck -S warning core/scripts/build-snapshot.sh tests/snapshot.test.sh` if installed — zero warnings.

- [ ] **Step 5: Run full suite, then commit**

Run: `bash tests/run.sh`
Expected: `failures=0`.

```bash
git add core/scripts/build-snapshot.sh tests/snapshot.test.sh
git commit -m "feat(snapshots): repo-level context pack builder + contract tests" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

### Task 2: Snapshot protocol + templates

**Files:**
- Create: `core/protocol/context-snapshots.md`
- Create: `core/templates/snapshot.md`, `core/templates/quality-baseline.md`, `core/templates/context-delta.md`
- Modify: `tests/templates.test.sh` (add the three template names to its existence list, matching its current assertion style)

**Interfaces:**
- Produces: protocol path `../protocol/context-snapshots.md` referenced by playbooks (Task 4) and role Inputs; template names `snapshot.md`, `quality-baseline.md`, `context-delta.md`.

- [ ] **Step 1: Write `core/protocol/context-snapshots.md`** — must contain exactly these rules (concise prose, mirror the style of `core/protocol/evidence.md`):
  - Pack location `.aidd/context/` (gitignored, never committed/pushed); built by `.aidd/framework/scripts/build-snapshot.sh <tag>`.
  - Rebuild cadence: every phase boundary + after every construction wave; tags `pre-<phase>`, `post-wave-<n>`.
  - Consumption rule: every role reads `snapshot.md` (+ `quality-baseline.md` where relevant) FIRST instead of re-crawling the repo; if the pack is missing, proceed and note the degradation explicitly.
  - Resume rule: never trusted across resume — rebuild before continuing ("re-prove, never trust"); gates never pin snapshot hashes.
  - History trail: `history/<UTC>-<tag>/` packs; the delta reviewer (`mode=delta`, Task 14) compares the `pre-<phase>` pack against the current one.
- [ ] **Step 2: Write the three templates** — each documents the file structure the script emits (headings shown in Task 1 Step 3) with a one-line "produced by build-snapshot.sh; do not hand-edit" note.
- [ ] **Step 3: Add the three names to `tests/templates.test.sh`; run `bash tests/run.sh`** — Expected: `failures=0`.
- [ ] **Step 4: Commit**

```bash
git add core/protocol/context-snapshots.md core/templates/snapshot.md core/templates/quality-baseline.md core/templates/context-delta.md tests/templates.test.sh
git commit -m "feat(snapshots): protocol + pack templates" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

### Task 3: Hook wrapper + gitignore plumbing

**Files:**
- Create: `hooks/scripts/build-snapshot.sh` (thin wrapper)
- Modify: `hooks/hooks.json` (register wrapper on the `Stop` event, alongside `gate-check.sh`)
- Modify: `install.sh` (append `.aidd/context/` to the target repo's `.gitignore`, creating file/entry if absent)
- Modify: `.gitignore` (this repo: add `.aidd/context/` line)
- Modify: `tests/hooks.test.sh`, `tests/install.test.sh` (assert wrapper registered / gitignore line appended, in each file's existing style)

**Interfaces:**
- Consumes: `core/scripts/build-snapshot.sh` from Task 1 (vendored at `.aidd/framework/scripts/build-snapshot.sh`).
- Produces: session-stop snapshot refresh on Claude Code; other runtimes rely on the orchestrator protocol duty (Task 4 playbook text).

- [ ] **Step 1: Write failing test additions** — `tests/hooks.test.sh`: assert `hooks.json` contains `build-snapshot.sh`; `tests/install.test.sh`: after a fixture install, assert target `.gitignore` contains `.aidd/context/` (and that running install twice does not duplicate the line).
- [ ] **Step 2: Run both suites — expect the new assertions to FAIL.**
- [ ] **Step 3: Implement** — wrapper mirrors the guard style of existing `hooks/scripts/*.sh`: silently exit 0 when `.aidd/` is absent (not an AIDD repo) or when `git` is unavailable; otherwise call the vendored script with tag `session-stop`. Add the hooks.json Stop entry. In `install.sh`, after vendoring: `grep -qxF '.aidd/context/' "${TARGET}/.gitignore" 2>/dev/null || echo '.aidd/context/' >> "${TARGET}/.gitignore"`.
- [ ] **Step 4: Run `bash tests/run.sh` — `failures=0`. Commit.**

```bash
git add hooks/scripts/build-snapshot.sh hooks/hooks.json install.sh .gitignore tests/hooks.test.sh tests/install.test.sh
git commit -m "feat(snapshots): stop-hook refresh + gitignore vendoring" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

### Task 4: Wire snapshots into playbooks, roles, docs; ADR 007

**Files:**
- Modify: `core/playbooks/00-pipeline.md` (orchestrator duties: rebuild pack at every phase boundary), `core/playbooks/30-construction.md` (rebuild after each wave, tag `post-wave-<n>`), `core/playbooks/20-inception.md` + `core/playbooks/40-qa.md` + `core/playbooks/50-delivery.md` (phase-boundary rebuild line)
- Modify: every file in `core/roles/` — insert one Inputs line: `` - `.aidd/context/snapshot.md` (+ `quality-baseline.md` where relevant) — read FIRST; do not re-crawl the repo. Missing pack → proceed and note the degradation. ``
- Create: `docs/context-snapshots.md` (user-facing summary, opens with `Canonical: core/protocol/context-snapshots.md`)
- Create: `docs/design/decisions/007-context-snapshots.md` (ADR format: Decision/Why/Consequence — Decision: repo-level gitignored context pack replaces per-agent repo crawling; Why: context-window relief + shared ground truth; Consequence: one rebuild per boundary/wave, packs disposable on resume)
- Modify: `README.md` (one feature bullet)

- [ ] **Step 1: Make all edits.** The role-Inputs sweep is mechanical — same line, every role file's `## Inputs` section, first bullet.
- [ ] **Step 2: Run `bash scripts/check-refs.sh` and `bash tests/run.sh`** — Expected: both green (new docs cross-references resolve).
- [ ] **Step 3: Commit**

```bash
git add core/playbooks core/roles docs/context-snapshots.md docs/design/decisions/007-context-snapshots.md README.md
git commit -m "feat(snapshots): wire pack into playbooks + all role inputs; ADR 007" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Stage 2 — Layer 2: Master Agent, Auditor, Tally, protocols, Supervisor

### Task 5: Schema — `audit` block + three new quality gates

**Files:**
- Modify: `core/schemas/change-state.schema.json`
- Modify: `core/templates/change-state.yaml`
- Create: `tests/fixtures/states/change-valid-audit.yaml`, `tests/fixtures/states/change-invalid-audit-overbudget.yaml`
- Modify: `tests/schemas.test.sh` (two new expectations)

**Interfaces:**
- Produces (exact keys later tasks + playbooks use): `quality_gates.auditor_approved`, `quality_gates.debate_complete`, `quality_gates.tally_reconciled` (enum `pending|passed|failed|na`); top-level optional `audit` object:

```json
"audit": {
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "interrogation": { "type": "object", "additionalProperties": false,
      "properties": { "rounds_used": {"type":"integer","minimum":0}, "max": {"type":"integer","minimum":1} },
      "required": ["rounds_used","max"] },
    "negotiation":   { "type": "object", "additionalProperties": false,
      "properties": { "exchanges_used": {"type":"integer","minimum":0}, "max": {"type":"integer","minimum":1} },
      "required": ["exchanges_used","max"] },
    "debate":        { "type": "object", "additionalProperties": false,
      "properties": { "exchanges_used": {"type":"integer","minimum":0}, "max": {"type":"integer","minimum":1} },
      "required": ["exchanges_used","max"] }
  },
  "required": ["interrogation","negotiation","debate"]
}
```

Template seed values: `rounds_used: 0, max: 2` / `exchanges_used: 0, max: 2` / `exchanges_used: 0, max: 6`.

- [ ] **Step 1: Write the failing tests** — `expect_valid` for `change-valid-audit.yaml` (a copy of `change-valid-mid-construction.yaml` plus the seeded `audit` block and the three new gates set `pending`); `expect_invalid` for `change-invalid-audit-overbudget.yaml` (same but `audit.debate.exchanges_used: "seven"` — wrong type).
- [ ] **Step 2: Run `bash tests/schemas.test.sh` — new checks FAIL** (unknown properties rejected by `additionalProperties:false`).
- [ ] **Step 3: Implement schema + template additions** (match the file's existing formatting; gates copy the enum shape of `critic_approved`).
- [ ] **Step 4: `bash tests/run.sh` — `failures=0`. Commit.**

```bash
git add core/schemas/change-state.schema.json core/templates/change-state.yaml tests/fixtures/states/change-valid-audit.yaml tests/fixtures/states/change-invalid-audit-overbudget.yaml tests/schemas.test.sh
git commit -m "feat(schema): audit budgets block + auditor/debate/tally quality gates" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

### Task 6: Rename master-supervisor → supervisor

**Files:**
- Rename: `core/roles/master-supervisor.md` → `core/roles/supervisor.md`; `agents/aidd-master-supervisor.md` → `agents/aidd-supervisor.md` (use `git mv`)
- Modify: every reference — sweep `core/playbooks/`, `core/protocol/`, `core/prompts/`, `core/AGENTS.md`, `agents/`, `docs/`, `skills/`, `core/templates/`, `commands/`, **and `tests/install.test.sh`** (asserts `.aidd/framework/roles/master-supervisor.md`). `CHANGELOG.md` history intentionally keeps the old name.

**Interfaces:**
- Produces: role path `../roles/supervisor.md`; agent name `aidd-supervisor` (frontmatter `name:` updated). All later tasks reference `supervisor`.

- [ ] **Step 1: `git mv` both files; update the agent wrapper frontmatter `name: aidd-supervisor` and its vendored path reference.**
- [ ] **Step 2: Sweep references:** `grep -rln 'master-supervisor' --include='*.md' --include='*.sh' --include='*.json' . | grep -v CHANGELOG` then fix every hit (`master-supervisor` → `supervisor`, `aidd-master-supervisor` → `aidd-supervisor`, "Master Supervisor" prose → "Supervisor").
- [ ] **Step 3: Verify:** `bash scripts/check-refs.sh && bash tests/run.sh` — both green; `grep -rn 'master-supervisor' . --include='*.md' --include='*.sh' | grep -v CHANGELOG` returns nothing.
- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: rename master-supervisor role to supervisor (Layer 3)" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

### Task 7: Interrogation protocol + templates

**Files:**
- Create: `core/protocol/interrogation.md`
- Create: `core/templates/interrogation-challenge.md`, `core/templates/interrogation-response.md`, `core/templates/auditor-verdict.md`
- Modify: `tests/templates.test.sh` (three names)

**Interfaces:**
- Produces: artifact paths `audit/interrogation/<subject-id>-round<N>-challenge.md`, `...-response.md`, `<subject-id>-verdict.md`; verdict vocabulary `PROVEN | DISPUTED` per AC; budget `max 2 rounds` (counted in state `audit.interrogation`).

- [ ] **Step 1: Write the protocol** — must specify: challenge names AC id + evidence gap + exact proof demanded; responses use the evidence-block format from `../protocol/evidence.md`; the orchestrator dispatches all parties (Auditor writes challenges; the challenged sub-agent is re-dispatched once per round to write the response); after round 2 every AC is `PROVEN` or `DISPUTED`; DISPUTED → `../protocol/negotiation.md`; applies per-wave in Construction (subjects = Builder Reports) and in QA final audit (subjects = tester/reviewer reports + AC-matrix rows).
- [ ] **Step 2: Templates:** challenge = table `AC id | evidence gap | proof demanded`; response = per-AC evidence blocks; auditor-verdict = table `AC id | verdict PROVEN|DISPUTED | evidence cited | note`.
- [ ] **Step 3: `bash tests/run.sh` green; commit** (`feat(layer2): interrogation protocol + templates`).

### Task 8: Negotiation protocol + template

**Files:**
- Create: `core/protocol/negotiation.md`, `core/templates/negotiation-log.md`
- Modify: `tests/templates.test.sh`

**Interfaces:**
- Produces: `audit/negotiation-log.md` (one appended section per disputed AC); trigger/short-circuit semantics; adjudication vocabulary `PROVEN | DEFECT | UNRESOLVABLE`; budget `max 2 exchanges` per AC (1 exchange = one position artifact + its response).

- [ ] **Step 1: Write the protocol** — exact semantics from the spec: trigger = Auditor DISPUTED **and** Master Agent monitoring accepts the work; short-circuit = Master Agent concurs → fix-loop defect directly (no negotiation); accept = fix-loop defect (no adjudication); contest = counter-evidence; exhaustion → Supervisor adjudicates (`PROVEN | DEFECT | UNRESOLVABLE`); `UNRESOLVABLE` → forced-human gate in both autonomy modes; every outcome mirrored to state `audit.negotiation` and the change history.
- [ ] **Step 2: Template:** per-AC section: Auditor position (+evidence) / Master Agent response accept|contest (+counter-evidence) / rounds table / final ruling + who ruled (negotiation, or Supervisor adjudication).
- [ ] **Step 3: `bash tests/run.sh` green; commit** (`feat(layer2): negotiation protocol + log template`).

### Task 9: Master Agent role + wrapper + monitoring template

**Files:**
- Create: `core/roles/master-agent.md`, `agents/aidd-master-agent.md`, `core/templates/monitoring-report.md`
- Modify: `tests/templates.test.sh`, `tests/manifest.test.sh` (if it enumerates agents — check and extend in its style)

**Interfaces:**
- Consumes: sub-agent reports (Builder Reports, `qa/*` reports), `.aidd/context/snapshot.md`, `audit/interrogation/*`.
- Produces: `audit/monitoring/<phase>-<step>.md` (template above); negotiation-log entries (accept/contest); debate-record contributions. Dispatched after every construction wave and every QA step batch.

- [ ] **Step 1: Write the role file.** Frontmatter: `role: master-agent`, `phase: construction (per wave) | qa (per step batch)`, `stage_class: adjudicative`, `tools: read-only code; writes audit/monitoring/*, own negotiation-log entries, own debate-record contributions`. Mission: judge *quality of work* in returning sub-agent reports — evidence convincing? work honest? corners cut? — never process compliance (Supervisor's job) and never dispatch mechanics (orchestrator's job). Protocol: read the batch's reports → per report, verify claims against cited evidence and the snapshot pack → write the monitoring note (concerns table: `report | concern | evidence | severity accept|challenge`) → answer Auditor negotiation positions when dispatched in negotiation mode (`mode: monitor` vs `mode: negotiate` parameter, like Reviewer's modes). Self-verification: every concern cites checkable evidence. Report format: `monitoring-report.md` template.
- [ ] **Step 2: Agent wrapper** — mirrors `agents/aidd-auditor.md` pattern (Task 10): "Read `.aidd/framework/roles/master-agent.md` and follow it exactly. Artifacts are your only channel."
- [ ] **Step 3: `bash tests/run.sh` + `bash scripts/check-refs.sh` green; commit** (`feat(layer2): master-agent monitoring role`).

### Task 10: Auditor role + wrapper

**Files:**
- Create: `core/roles/auditor.md`, `agents/aidd-auditor.md`
- Modify: `tests/manifest.test.sh` (as in Task 9)

**Interfaces:**
- Consumes: story files (`ac_ids`), Builder Reports, `qa/tests/*`, `qa/findings*`, `ac-matrix.md`, Jira read ladder (`../protocol/jira-sync.md`), snapshot pack.
- Produces: `audit/interrogation/*` challenges + verdicts (`PROVEN | DISPUTED` per AC, Task 7 templates); negotiation positions; debate contributions; appended `## Auditor Report` section per story file.

- [ ] **Step 1: Write the role file.** Frontmatter: `role: auditor`, `phase: construction (per wave) | qa (final audit)`, `stage_class: adjudicative`, `tools: read-only code + Bash probes (.aidd/probes/ only, never committed); writes audit/interrogation/*, own negotiation-log entries, own debate-record contributions; appends Auditor Report to story files`. Mission: validate every sub-agent's work against the acceptance criteria it claims — Jira stories, tasks, bugs, and custom types — by direct artifact interrogation; you win by finding unproven ACs. Protocol: per subject → map claimed ACs → demand proof for every gap via challenge round (max 2, `../protocol/interrogation.md`) → verdict per AC → DISPUTED goes to `../protocol/negotiation.md` → append `## Auditor Report` to each story. Self-verification: no DISPUTED without a named evidence gap; no PROVEN without cited executed evidence. Report format: `auditor-verdict.md` template.
- [ ] **Step 2: Wrapper + tests green; commit** (`feat(layer2): auditor interrogation role`).

### Task 11: Tally role + wrapper + template

**Files:**
- Create: `core/roles/tally.md`, `agents/aidd-tally.md`, `core/templates/tally.md`
- Modify: `tests/templates.test.sh`, `tests/manifest.test.sh`

**Interfaces:**
- Consumes: Jira read ladder, `prd.md` AC table, `stories/*` frontmatter + Builder Reports, Construction diff (`git diff`), `qa/test-report.md`, `evidence/manifest.md` (+ `evidence/pre/`, `evidence/post/`).
- Produces: `qa/tally.md` — one row per work item: `item id | type | ACs | stories | diff files | tests | pre evidence | post evidence | verdict RECONCILED|GAP` + `## Orphans` section (diff files traceable to no work item). Sets nothing itself; orchestrator folds into `quality_gates.tally_reconciled`.

- [ ] **Step 1: Write the role file.** Frontmatter: `role: tally`, `phase: qa (after post evidence, before critic)`, `stage_class: mechanical`, `tools: read-only code + Jira read ladder; writes qa/tally.md only`. Mission: tally every tracked work item the change references (stories, tasks, bugs, custom types) against the implementation, binding each to its before/after evidence. Protocol: enumerate items (Jira ticket + PRD ACs + story frontmatter) → join to stories/diff/tests/evidence-manifest rows → verdict per row (`RECONCILED` only when every column is non-empty or explicitly `na` with reason; else `GAP`) → orphan scan (diff files not owned by any story's file_scope) → route: missing AC proof → note for AC-matrix fix loop; orphaned diff → finding row for adversarial verification. Self-verification: every RECONCILED row's evidence paths exist on disk. Report format: `tally.md` template.
- [ ] **Step 2: Template `core/templates/tally.md`** with the exact table header above + Orphans section + Tally line (`items: N, reconciled: N, gaps: N, orphans: N`).
- [ ] **Step 3: Tests green; commit** (`feat(layer2): tally reconciliation role — jira items <-> implementation <-> pre/post evidence`).

### Task 12: Supervisor super-context + supervision protocol + playbook rewrites

**Files:**
- Modify: `core/roles/supervisor.md` (Inputs + adjudication duty), `core/protocol/supervision.md` (checklists), `core/playbooks/00-pipeline.md` (three-layer description), `core/playbooks/30-construction.md` (wave steps), `core/playbooks/40-qa.md` (renumbered steps incl. Tally + final audit + negotiation)

**Interfaces:**
- Consumes: everything Tasks 5–11 produced (paths + vocabularies above).
- Produces: the canonical phase flows every runtime follows.

- [ ] **Step 1: `supervisor.md`:** Inputs gain `audit/monitoring/*`, `audit/interrogation/*`, `audit/negotiation-log.md`, `audit/debate/*`, `qa/tally.md`, the Critic verdict (the super-context). New Protocol step: adjudicate exhausted negotiations per `../protocol/negotiation.md` (`PROVEN | DEFECT | UNRESOLVABLE`, appended to the negotiation log, mirrored to state `audit`); phase verdict stays `COMPLIANT | VIOLATIONS` — adjudication is a distinct additional output.
- [ ] **Step 2: `supervision.md`** phase checklists add: Construction — monitoring note per wave present; interrogation verdicts complete per wave; budgets respected. QA — debate records present with budget arithmetic consistent with state; tally complete with zero unwaived gaps; negotiation log terminal (no dangling DISPUTED).
- [ ] **Step 3: `30-construction.md`** — after step 2b (TDD evidence check), insert: 2c Master Agent monitoring over the wave's Builder Reports; 2d Auditor interrogation (max 2 rounds) → verdicts; DISPUTED → negotiation (short-circuit rule); then the existing wave integration check becomes 2e. Snapshot rebuild `post-wave-<n>` (Task 4) stays last.
- [ ] **Step 4: `40-qa.md`** — rewrite steps in the spec's order: post-review dimensions **incl. `mode=delta` (placeholder note: added by Task 14)** → collate → adversarial verification → **test-design debate** (placeholder note: protocol added by Task 15) → test execution + execution debate → fix loop → E2E → post evidence → AC matrix → results debate → **Tally reconciliation → `tally_reconciled`** → **Auditor final audit + interrogation** → negotiation if triggered → test-report approval → QA verdict/score → Critic → **Supervisor audit over the super-context** → GATE G3. Sets `auditor_approved` (all ACs PROVEN or ruled) — `debate_complete` is set by Task 15's steps. Exit checklist gains: `auditor_approved` passed, `tally_reconciled` passed, negotiation log terminal.
- [ ] **Step 5: `00-pipeline.md`** — add a "Three verification layers" paragraph (workers / Master Agent + Auditor + Tally / Supervisor super-context) and the per-boundary dispatch list.
- [ ] **Step 6: `bash scripts/check-refs.sh && bash tests/run.sh` green; commit** (`feat(layer2): supervisor super-context + playbook wiring`).

### Task 13: ADR 006 + Layer-2 docs

**Files:**
- Create: `docs/design/decisions/006-three-layer-verification.md`, `docs/three-layer-verification.md`
- Modify: `docs/supervision.md`, `README.md`

- [ ] **Step 1: ADR 006** (Decision/Why/Consequence): dedicated Layer-2 Master Agent + Auditor + Tally with artifact interrogation/negotiation; blocking economy amended — an AC exiting the interrogation → negotiation → adjudication ladder as DISPUTED/DEFECT blocks via the fix loop; ladder can terminate early (concur short-circuit; accept skips adjudication); non-AC items advisory. Why: precision over speed, catch AC gaps per wave. Consequence: ~2 adjudicative dispatches per wave + QA batch cost; hard budgets cap it.
- [ ] **Step 2: `docs/three-layer-verification.md`** — user-facing walkthrough (opens `Canonical: core/playbooks/00-pipeline.md`), the three layers, one worked example of a disputed AC travelling the ladder. Update `docs/supervision.md` for the rename + adjudication. README: layer diagram bullet.
- [ ] **Step 3: `check-refs` + suite green; commit** (`docs: ADR 006 + three-layer verification docs`).

---

## Stage 3 — Delta review

### Task 14: Reviewer `mode=delta` + ADR 008

**Files:**
- Modify: `core/roles/reviewer.md` (add the third mode), `core/playbooks/40-qa.md` (replace Task 12's placeholder note: `mode=delta` joins the step-1 fan-out), `docs/phases/qa.md` (dimension list)
- Create: `docs/design/decisions/008-delta-review.md`

**Interfaces:**
- Consumes: `.aidd/context/history/` pre-phase pack + current pack (Task 1), `pre-review/<dimension>.md` (existing Inception artifacts), Construction diff.
- Produces: `qa/findings-delta.md` in the standard `qa-findings.md` row format → existing funnel.

- [ ] **Step 1: Extend `reviewer.md`:** `mode=delta` — inputs exactly: the `pre-<phase>` snapshot pack from `.aidd/context/history/`, the per-dimension `pre-review/<dimension>.md` set (plan intent), the full Construction diff, current `quality-baseline.md` vs the pre pack's. Three judged bindings, each producing findings rows: **intent-fidelity** (implementation honors the plan's intent, not merely green tests), **structure-fit** (diff matches repo conventions per the snapshot structure map), **sigma-regression** (measured quality regressed beyond tolerance: coverage down, complexity/file-size hotspots up, lint broken — cite baseline vs current numbers). Findings without a concrete failure scenario remain invalid by format.
- [ ] **Step 2: `40-qa.md` step 1** gains dimension `delta` → `qa/findings-delta.md`. ADR 008 (Decision: pre/post-bound review as a reviewer mode, not a new role; Why: parameterized roles beat duplicates; Consequence: needs snapshot history, findings enter the standard funnel).
- [ ] **Step 3: `check-refs` + suite green; commit** (`feat(delta-review): reviewer mode=delta binding pre-snapshot, intent, and sigmas`).

---

## Stage 4 — Continuous test debate + Playwright MCP

### Task 15: Debate protocol + test-engineer wiring + ADR 009

**Files:**
- Create: `core/protocol/test-debate.md`, `core/templates/debate-record.md`
- Modify: `core/roles/test-engineer.md` (publish-before-execute + debate participation), `core/roles/master-agent.md` + `core/roles/auditor.md` (debate duties cross-reference), `core/playbooks/40-qa.md` (replace Task 12's debate placeholder notes with protocol references; set `debate_complete`), `tests/templates.test.sh`
- Create: `docs/design/decisions/009-continuous-test-debate.md`
- Modify: `docs/testing.md`

**Interfaces:**
- Produces: `audit/debate/<category>.md` records; accounting unit (1 exchange = challenge artifact + response pair; batched design round = 1 exchange); per-surface caps 2/2/2 under dominant shared cap 6, no rollover; draw order design → execution → results; exhaustion → AC-mapped items DISPUTED → negotiation; unmapped items advisory. State counter `audit.debate.exchanges_used`.

- [ ] **Step 1: Write `test-debate.md`** with exactly the accounting + caps + mapping rules above, the three surfaces (design: TC matrices challenged before execution; execution: contested TCs re-executed, batched per wave, 2 exchanges total on the surface; results: disputed PASSes re-proven live — **Playwright MCP** browser runs for UI-facing flows with screenshots as evidence, CLI/API transcripts otherwise, explicit fallback to `core/templates/playwright-capture.mjs` where MCP is unavailable), and the learning feed (invalidated designs → `learnings.md`).
- [ ] **Step 2: `test-engineer.md`:** Protocol now: design matrix → **publish for debate, wait for verdict or amend (max per protocol)** → execute → answer execution contests on your TCs only → consolidated results. `debate-record.md` template: surface, exchange table (`# | challenger | claim | response | outcome amended|defended`), budget arithmetic line.
- [ ] **Step 3: `40-qa.md`** debate steps now cite `../protocol/test-debate.md`; orchestrator sets `debate_complete` when all surfaces closed within budget. ADR 009. `docs/testing.md` debate section.
- [ ] **Step 4: `check-refs` + suite green; commit** (`feat(debate): continuous test-debate protocol with Playwright MCP live re-proof`).

### Task 16: Release v0.3.0

**Files:**
- Modify: `VERSION` (`0.3.0`), `CHANGELOG.md` (v0.3.0 section: three layers, Tally, snapshots, delta review, test debate, rename note), `ROADMAP.md` (tick delivered items), `core/prompts/qa.md` + `core/prompts/construction.md` + `commands/*.md` if they enumerate roles/steps (sweep for stale step lists)

- [ ] **Step 1: Sweep `core/prompts/` and `commands/` for any enumerated QA/Construction steps or role lists that Tasks 6–15 changed; update them.**
- [ ] **Step 2: Final verification:** `bash tests/run.sh` (`failures=0`), `bash scripts/check-refs.sh`, `grep -rn 'master-supervisor' --include='*.md' --include='*.sh' . | grep -v CHANGELOG` empty, `python3 core/scripts/aidd-validate.py core/schemas/change-state.schema.json` against both new fixtures.
- [ ] **Step 3: Commit** (`chore(release): v0.3.0 — three-layer verification, tally, snapshots, delta review, test debate`).

---

## Self-review notes

- Spec coverage: Layer 2 agents (Tasks 9–11), Supervisor (6, 12), interrogation (7), negotiation (8), blocking economy (13 ADR), snapshots (1–4), delta review (14), debate + Playwright MCP (15), Tally (11), schema/gates (5), rename incl. tests/install.test.sh (6), docs/ADRs (4, 13, 14, 15), release (16). No spec section unassigned.
- Cross-task names verified: gate keys, `audit.*` fields, verdict vocabularies, artifact paths, and template names are identical in every task that uses them (see Global Constraints).
- Placeholder scan: the two "placeholder note" markers in Task 12 are deliberate forward-references resolved by Tasks 14–15 within this plan, not TBDs.
