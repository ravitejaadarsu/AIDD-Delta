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
