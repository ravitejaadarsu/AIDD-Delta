#!/usr/bin/env bash
# Snapshot builder contract tests, run against the sample-project fixture.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
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

ok() { # desc, then the assertion as a command (keeps $? off a bare condition)
  if "${@:2}"; then check "$1" 0; else check "$1" 1; fi
}

# 1. Builds all four artifacts
( cd "${TMP}" && bash "${ROOT}/core/scripts/build-snapshot.sh" post-wave-1 >/dev/null )
ok "snapshot.md created"         test -f "${TMP}/.aidd/context/snapshot.md"
ok "quality-baseline.md created" test -f "${TMP}/.aidd/context/quality-baseline.md"
ok "delta.md created"            test -f "${TMP}/.aidd/context/delta.md"
hist_tagged="$(find "${TMP}/.aidd/context/history" -maxdepth 1 -type d -name '*-post-wave-1' | head -1)"
ok "history dir tagged" test -n "${hist_tagged}"

# 2. Idempotent: second run succeeds and history accumulates
( cd "${TMP}" && bash "${ROOT}/core/scripts/build-snapshot.sh" post-wave-2 >/dev/null )
hist_count="$(find "${TMP}/.aidd/context/history" -mindepth 1 -maxdepth 1 -type d | wc -l)"
ok "history accumulates" test "${hist_count}" -ge 2

# 3. delta.md references changes since previous snapshot
grep -q "## Delta" "${TMP}/.aidd/context/delta.md"; check "delta section present" $?

# 4. Refuses to run outside a git repo
NOGIT="$(mktemp -d)"
( cd "${NOGIT}" && bash "${ROOT}/core/scripts/build-snapshot.sh" x >/dev/null 2>&1 )
[ $? -ne 0 ]; check "non-git repo rejected" $?
rm -rf "${NOGIT}"

# 5. quality-baseline rows carry evidence commands (evidence protocol)
grep -q '\$' "${TMP}/.aidd/context/quality-baseline.md"; check "baseline shows commands" $?

# 6. snapshot.md carries the spec'd public-API-surface section
grep -q '^## Public API surface$' "${TMP}/.aidd/context/snapshot.md"; check "API surface section present" $?

# 7. Coverage + Lint sections always exist with an explicit na row (explicit degradation)
grep -q '^## Coverage$' "${TMP}/.aidd/context/quality-baseline.md"; check "coverage section present" $?
grep -q '^## Lint$' "${TMP}/.aidd/context/quality-baseline.md";     check "lint section present" $?
grep -q '^coverage: na (' "${TMP}/.aidd/context/quality-baseline.md"; check "coverage na row explicit" $?
grep -q '^lint: na ('     "${TMP}/.aidd/context/quality-baseline.md"; check "lint na row explicit" $?

# 8. Verify zero-match exit codes are not recorded as [exit 1] (fix for grep pipefail bug)
if ! grep -q '\[exit 1\]' "${TMP}/.aidd/context/quality-baseline.md"; then
  check "baseline exit codes clean" 0
else
  check "baseline exit codes clean" 1
fi

exit "${fail}"
