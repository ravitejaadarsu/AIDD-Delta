#!/usr/bin/env bash
# Contract tests for the execution-environment surface: sandboxed test runs,
# model routing, and the native git-hook integration.
#
# The properties under test are the ones whose failure is silent: a sandbox
# that degrades without saying so, a routing gap that stops a run instead of
# falling back, and a hook install that eats another tool's hook.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
fail=0
ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

check() { if [ "$2" -ne 0 ]; then echo "FAIL: $1"; fail=1; fi; }
ok()    { if "${@:2}"; then check "$1" 0; else check "$1" 1; fi; }

SB="${ROOT}/core/scripts/aidd-sandbox.sh"
RT="${ROOT}/core/scripts/aidd-route.sh"
HK="${ROOT}/core/scripts/aidd-install-hooks.sh"
CFG="${ROOT}/core/templates/config.json"

for f in "${SB}" "${RT}" "${HK}" "${CFG}"; do
  [ -f "${f}" ] || { echo "FAIL: missing ${f}"; fail=1; }
done

# ── 1. Sandbox: explicit opt-out runs on the host and says so ──────────────
out="$(AIDD_SANDBOX=off bash "${SB}" -- echo sandboxed-ok 2>"${TMP}/err")"
ok "opt-out still runs the command" test "${out}" = "sandboxed-ok"
grep -q 'disabled by AIDD_SANDBOX=off' "${TMP}/err"
check "opt-out is announced on stderr" $?

# The command's own exit code is what the caller sees.
AIDD_SANDBOX=off bash "${SB}" -- sh -c 'exit 7' 2>/dev/null
ok "command exit code is preserved" test $? -eq 7

# No command at all is a sandbox-level failure (125), distinct from a test failure.
bash "${SB}" -- >/dev/null 2>&1
ok "missing command exits 125, distinct from any test exit" test $? -eq 125

# Degradation must be loud. With no runtime available the command still runs,
# but the reason is on stderr for the run's degradation record.
if ! command -v docker >/dev/null 2>&1 && ! command -v podman >/dev/null 2>&1; then
  out="$(bash "${SB}" -- echo degraded-ok 2>"${TMP}/err2")"
  ok "degrades to host execution" test "${out}" = "degraded-ok"
  grep -q 'DEGRADED' "${TMP}/err2"
  check "degradation is announced, never silent" $?
  grep -q 'evidence.md' "${TMP}/err2"
  check "degradation cites the evidence discipline" $?

  # Required mode converts the same situation into a hard failure.
  AIDD_SANDBOX_REQUIRED=1 bash "${SB}" -- echo nope >/dev/null 2>"${TMP}/err3"
  ok "AIDD_SANDBOX_REQUIRED=1 refuses to run on the host" test $? -eq 125
  grep -q 'REQUIRED sandbox unavailable' "${TMP}/err3"
  check "refusal states the reason" $?
else
  echo "   (container runtime present; degradation exercised via a stripped PATH)"
fi

# Exercise the degradation path unconditionally by hiding any runtime behind a
# PATH with no docker/podman on it. Without this, a CI image that ships docker
# would never test the branch that matters most — the loud fallback.
mkdir -p "${TMP}/bin"
for tool in bash sh env git grep id printf echo python3 dirname sed; do
  src="$(command -v "${tool}" 2>/dev/null)" && ln -sf "${src}" "${TMP}/bin/${tool}"
done
out="$(PATH="${TMP}/bin" bash "${SB}" -- echo forced-degrade 2>"${TMP}/err4")"
ok "degrades to host when no runtime is on PATH" test "${out}" = "forced-degrade"
grep -q 'DEGRADED' "${TMP}/err4"
check "forced degradation is announced, never silent" $?
grep -q 'no podman or docker on PATH' "${TMP}/err4"
check "forced degradation names the missing runtime" $?

PATH="${TMP}/bin" AIDD_SANDBOX_REQUIRED=1 bash "${SB}" -- echo nope >/dev/null 2>"${TMP}/err5"
ok "required mode refuses when no runtime is on PATH" test $? -eq 125
grep -q 'refusing to run on the host' "${TMP}/err5"
check "required-mode refusal is explicit" $?

# ── 2. Routing: resolution, fallback, cost, and the credential audit ───────
export AIDD_CONFIG="${CFG}"

ok "adversarial routes to a frontier model" \
  test "$(bash "${RT}" model adversarial)" = "claude-opus-5"
ok "mechanical routes to a cheap model" \
  test "$(bash "${RT}" model mechanical)" = "claude-haiku-4-5"
ok "effort hint is carried per class" \
  test "$(bash "${RT}" effort adversarial)" = "xhigh"

# A routing gap must degrade to the default, never stop the run.
ok "unmapped class falls back to the default" \
  test "$(bash "${RT}" model no-such-class)" = "claude-opus-5"
ok "missing config still resolves a model" \
  test "$(AIDD_CONFIG=/nonexistent/config.json bash "${RT}" model review)" = "claude-opus-5"

# Cost is derived from the configured rate; an unpriced model reports `na`,
# never 0 — a zero in a measured column reads as free.
ok "cost is computed from the configured rate" \
  test "$(bash "${RT}" cost claude-opus-5 1000000 0)" = "5.000000"
ok "unpriced model reports na, never zero" \
  test "$(bash "${RT}" rate not-a-model)" = "na na"
ok "unpriced cost reports na, never zero" \
  test "$(bash "${RT}" cost not-a-model 1000 1000)" = "na"

bash "${RT}" table | grep -q 'adversarial'
check "table renders every configured class" $?

# The shipped template must itself be clean, and the audit must catch a plant.
bash "${RT}" audit >/dev/null 2>&1
check "shipped config template passes the credential audit" $?
python3 - "${CFG}" "${TMP}/bad.json" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
cfg["models"]["api_key"] = "sk-ant-notarealkeyvalue123456"
json.dump(cfg, open(sys.argv[2], "w", encoding="utf-8"))
PY
AIDD_CONFIG="${TMP}/bad.json" bash "${RT}" audit >/dev/null 2>&1
ok "audit fails on a credential-shaped entry" test $? -eq 1
unset AIDD_CONFIG

# ── 3. Hook install: opt-in, idempotent, reversible, non-destructive ───────
mkdir -p "${TMP}/repo"
git -C "${TMP}/repo" init -q
printf 'seed\n' > "${TMP}/repo/seed.txt"
git -C "${TMP}/repo" add -A
git -C "${TMP}/repo" -c user.email=t@t -c user.name=t commit -qm init

HOOK="${TMP}/repo/.git/hooks/pre-commit"

# A pre-existing foreign hook must survive installation.
printf '#!/usr/bin/env bash\necho FOREIGN-HOOK-RAN\nexit 0\n' > "${HOOK}"
chmod +x "${HOOK}"

( cd "${TMP}/repo" && bash "${HK}" >/dev/null 2>&1 )
ok "hook installed" test -x "${HOOK}"
grep -q 'AIDD pre-commit hook' "${HOOK}"
check "installed hook carries the AIDD marker" $?
ok "foreign hook preserved, not overwritten" test -f "${TMP}/repo/.git/hooks/pre-commit.pre-aidd"
grep -q 'FOREIGN-HOOK-RAN' "${TMP}/repo/.git/hooks/pre-commit.pre-aidd"
check "preserved hook still holds the original body" $?

# Idempotent: a second install must not stack hooks.
( cd "${TMP}/repo" && bash "${HK}" >/dev/null 2>&1 )
markers="$(grep -c 'AIDD pre-commit hook' "${HOOK}")"
ok "re-install does not stack duplicate hooks" test "${markers}" -le 2

# The chained foreign hook must actually run on commit.
printf 'more\n' > "${TMP}/repo/second.txt"
git -C "${TMP}/repo" add -A
commit_out="$(git -C "${TMP}/repo" -c user.email=t@t -c user.name=t commit -m second 2>&1)"
printf '%s' "${commit_out}" | grep -q 'FOREIGN-HOOK-RAN'
check "chained foreign hook runs during commit" $?

# Reversible: uninstall restores exactly what was there before.
( cd "${TMP}/repo" && bash "${HK}" --uninstall >/dev/null 2>&1 )
grep -q 'FOREIGN-HOOK-RAN' "${HOOK}"
check "uninstall restores the original hook" $?
ok "uninstall removes the preserved copy" test ! -f "${TMP}/repo/.git/hooks/pre-commit.pre-aidd"

# Opt-out escape hatch exists for a developer mid-emergency.
grep -q 'AIDD_HOOK:-on' "${HK}"
check "hook honors an AIDD_HOOK=off escape hatch" $?

# ── 4. The CI workflow is wired to the same scripts ────────────────────────
WF="${ROOT}/.github/workflows/aidd-review.yml"
ok "review workflow exists" test -f "${WF}"
grep -q 'aidd-route.sh audit' "${WF}"
check "CI audits the routing config" $?
grep -q 'aidd-index.py' "${WF}"
check "CI builds the index" $?
grep -q 'merge-base' "${WF}"
check "CI resolves the merge base" $?
grep -q 'tests/run.sh' "${WF}"
check "CI runs the self-tests" $?

exit "${fail}"
