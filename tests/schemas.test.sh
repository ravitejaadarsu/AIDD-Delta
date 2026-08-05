#!/usr/bin/env bash
# Schema contract tests: valid fixtures must validate, invalid must be rejected.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

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
expect_valid   "${S}/change-state.schema.json" "${F}/change-valid-audit.yaml"
# A rigor-skipped gate must be able to record its mandated reason (protocol/gates.md
# §The `na` encoding): the object form validates, and it is closed around {status, reason}.
expect_valid   "${S}/change-state.schema.json" "${F}/change-valid-gate-reason.yaml"
expect_invalid "${S}/change-state.schema.json" "${F}/change-invalid-gate-no-status.yaml"
expect_invalid "${S}/change-state.schema.json" "${F}/change-invalid-gate-extra-key.yaml"
# Ledger minutes are recorded to one decimal, so the cost minute fields are not integers.
expect_valid   "${S}/change-state.schema.json" "${F}/change-valid-cost-decimal.yaml"
expect_invalid "${S}/change-state.schema.json" "${F}/change-invalid-bad-phase.yaml"
expect_invalid "${S}/change-state.schema.json" "${F}/change-invalid-missing-mode.yaml"
expect_invalid "${S}/change-state.schema.json" "${F}/change-invalid-audit-overbudget.yaml"
expect_invalid "${S}/change-state.schema.json" "${F}/change-invalid-rigor-mode.yaml"
expect_invalid "${S}/change-state.schema.json" "${F}/change-invalid-cost-disposition.yaml"
expect_invalid "${S}/change-state.schema.json" "${F}/change-invalid-escape-layer.yaml"
expect_invalid "${S}/change-state.schema.json" "${F}/change-invalid-determinism-source.yaml"
expect_valid_fm   "${S}/story-frontmatter.schema.json" "${F}/story-valid.md"
expect_invalid_fm "${S}/story-frontmatter.schema.json" "${F}/story-invalid.md"

# ── validator: oneOf, the keyword the two gate encodings rest on.
# Exactly-one-branch semantics, both directions, plus an error message that names the forms.
TMP="tests/tmp/schemas-$$"
mkdir -p "${TMP}"
cleanup() { rm -rf "${TMP}"; }
trap cleanup EXIT

cat > "${TMP}/oneof.schema.json" <<'JSON'
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "gate": { "oneOf": [
      { "enum": ["passed", "na"] },
      { "type": "object", "required": ["status"], "additionalProperties": false,
        "properties": { "status": { "enum": ["passed", "na"] }, "reason": { "type": "string" } } }
    ] },
    "ambiguous": { "oneOf": [{ "type": "string" }, { "type": "string" }] }
  }
}
JSON

printf 'gate: passed\n'                          > "${TMP}/oneof-scalar.yaml"
printf 'gate:\n  status: na\n  reason: "x"\n'    > "${TMP}/oneof-object.yaml"
printf 'gate: maybe\n'                           > "${TMP}/oneof-neither.yaml"
printf 'ambiguous: "both branches match"\n'      > "${TMP}/oneof-ambiguous.yaml"

expect_valid   "${TMP}/oneof.schema.json" "${TMP}/oneof-scalar.yaml"
expect_valid   "${TMP}/oneof.schema.json" "${TMP}/oneof-object.yaml"
expect_invalid "${TMP}/oneof.schema.json" "${TMP}/oneof-neither.yaml"
expect_invalid "${TMP}/oneof.schema.json" "${TMP}/oneof-ambiguous.yaml"

msg="$(python3 core/scripts/aidd-validate.py "${TMP}/oneof.schema.json" "${TMP}/oneof-neither.yaml" 2>&1)"
if ! printf '%s\n' "${msg}" | grep -q 'matches none of the 2 allowed forms'; then
  echo "oneOf error must name how many forms were tried; got: ${msg}"
  fail=1
fi
if ! printf '%s\n' "${msg}" | grep -q "form 2: "; then
  echo "oneOf error must report why each form failed; got: ${msg}"
  fail=1
fi
msg="$(python3 core/scripts/aidd-validate.py "${TMP}/oneof.schema.json" "${TMP}/oneof-ambiguous.yaml" 2>&1)"
if ! printf '%s\n' "${msg}" | grep -q 'expected exactly one'; then
  echo "oneOf must reject an instance matching more than one form; got: ${msg}"
  fail=1
fi

exit "${fail}"
