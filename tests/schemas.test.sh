#!/usr/bin/env bash
# Schema contract tests: valid fixtures must validate, invalid must be rejected.
set -uo pipefail
cd "$(dirname "$0")/.."

S=core/schemas
F=tests/fixtures/states
fail=0

expect_valid() { # schema file
  if ! python3 core/scripts/aidd-validate.py "$1" "$2" >/dev/null 2>&1; then
    echo "expected VALID: $2 against $1"
    python3 core/scripts/aidd-validate.py "$1" "$2" || true
    fail=1
  fi
}

expect_invalid() {
  if python3 core/scripts/aidd-validate.py "$1" "$2" >/dev/null 2>&1; then
    echo "expected INVALID but validated: $2 against $1"
    fail=1
  fi
}

expect_valid_fm() {
  if ! python3 core/scripts/aidd-validate.py --frontmatter "$1" "$2" >/dev/null 2>&1; then
    echo "expected VALID (frontmatter): $2 against $1"
    python3 core/scripts/aidd-validate.py --frontmatter "$1" "$2" || true
    fail=1
  fi
}

expect_invalid_fm() {
  if python3 core/scripts/aidd-validate.py --frontmatter "$1" "$2" >/dev/null 2>&1; then
    echo "expected INVALID (frontmatter) but validated: $2 against $1"
    fail=1
  fi
}

expect_valid   "${S}/state.schema.json"        "${F}/global-valid.yaml"
expect_valid   "${S}/change-state.schema.json" "${F}/change-valid-fresh.yaml"
expect_valid   "${S}/change-state.schema.json" "${F}/change-valid-mid-construction.yaml"
expect_valid   "${S}/change-state.schema.json" "${F}/change-valid-awaiting-gate.yaml"
expect_invalid "${S}/change-state.schema.json" "${F}/change-invalid-bad-phase.yaml"
expect_invalid "${S}/change-state.schema.json" "${F}/change-invalid-missing-mode.yaml"
expect_valid_fm   "${S}/story-frontmatter.schema.json" "${F}/story-valid.md"
expect_invalid_fm "${S}/story-frontmatter.schema.json" "${F}/story-invalid.md"

exit "${fail}"
