#!/usr/bin/env bash
# AIDD Delta self-test runner. Zero hard dependencies: bash + python3 stdlib.
# shellcheck and markdownlint-cli2 run only when installed (CI installs them).
set -uo pipefail
cd "$(dirname "$0")/.."

failures=0
suites=0

run_suite() {
  suite="$1"
  suites=$((suites + 1))
  echo "── ${suite}"
  if bash "${suite}"; then
    echo "   PASS ${suite}"
  else
    echo "   FAIL ${suite}"
    failures=$((failures + 1))
  fi
}

shopt -s nullglob
for t in tests/*.test.sh; do
  run_suite "${t}"
done
shopt -u nullglob

if command -v shellcheck >/dev/null 2>&1; then
  echo "── shellcheck"
  sh_targets=()
  for f in install.sh scripts/*.sh hooks/scripts/*.sh tests/run.sh tests/*.test.sh; do
    [ -e "${f}" ] && sh_targets+=("${f}")
  done
  if [ "${#sh_targets[@]}" -gt 0 ] && ! shellcheck -S warning "${sh_targets[@]}"; then
    failures=$((failures + 1))
  fi
else
  echo "── shellcheck not installed; skipping (CI runs it)"
fi

if command -v markdownlint-cli2 >/dev/null 2>&1; then
  echo "── markdownlint"
  if ! markdownlint-cli2 "**/*.md" "#node_modules"; then
    failures=$((failures + 1))
  fi
else
  echo "── markdownlint-cli2 not installed; skipping (CI runs it)"
fi

echo "suites=${suites} failures=${failures}"
[ "${failures}" -eq 0 ]
