#!/usr/bin/env bash
# AIDD Delta self-test runner. Zero hard dependencies: bash + python3 stdlib.
# Lint tools (ShellCheck, markdownlint-cli2) run only when installed; CI installs them.
# NOTE: a comment must not begin with the word "shellcheck" — it parses as a directive.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# Pinned lint toolchain. CI installs these exact versions; local runs fall back to
# `npx -y markdownlint-cli2@${MDLINT_VERSION}` so both lint byte-identically.
MDLINT_VERSION="0.18.1"

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
  for f in install.sh scripts/*.sh hooks/scripts/*.sh core/scripts/*.sh \
           core/templates/*.sh tests/run.sh tests/*.test.sh; do
    [ -e "${f}" ] && sh_targets+=("${f}")
  done
  if [ "${#sh_targets[@]}" -gt 0 ] && ! shellcheck -S warning "${sh_targets[@]}"; then
    failures=$((failures + 1))
  fi
elif [ "${AIDD_STRICT_LINT:-0}" = "1" ]; then
  echo "── FAIL shellcheck unavailable and AIDD_STRICT_LINT=1 (CI must lint)"
  failures=$((failures + 1))
else
  echo "── shellcheck not installed; skipping"
fi

MD_GLOBS=("**/*.md" "#node_modules" "#.superpowers" "#.aidd")

mdlint() { # pinned so local and CI lint identically — never unpin (see .markdownlint.jsonc)
  if command -v markdownlint-cli2 >/dev/null 2>&1; then
    markdownlint-cli2 "${MD_GLOBS[@]}"
  elif command -v npx >/dev/null 2>&1; then
    npx -y "markdownlint-cli2@${MDLINT_VERSION}" "${MD_GLOBS[@]}"
  else
    return 127
  fi
}

echo "── markdownlint (pinned ${MDLINT_VERSION})"
mdlint; md_status=$?
if [ "${md_status}" -eq 0 ]; then
  :
elif [ "${md_status}" -eq 127 ]; then
  if [ "${AIDD_STRICT_LINT:-0}" = "1" ]; then
    echo "   FAIL markdownlint unavailable and AIDD_STRICT_LINT=1 (CI must lint)"
    failures=$((failures + 1))
  else
    echo "   markdownlint unavailable (no markdownlint-cli2, no npx); skipping"
  fi
else
  failures=$((failures + 1))
fi

echo "suites=${suites} failures=${failures}"
[ "${failures}" -eq 0 ]
