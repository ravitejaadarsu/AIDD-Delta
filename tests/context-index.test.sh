#!/usr/bin/env bash
# Contract tests for the query-locally context surface: the dual-state index,
# just-in-time symbol reads, and test-log redaction.
#
# These assert the properties the whole design rests on — hash-gated reuse, no
# stale span ever served, and signal survival through redaction — because each
# is silent when it breaks: a stale span still prints, and an over-eager
# redactor still returns a confident-looking summary.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
fail=0
ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

check() { # desc, exit-code
  if [ "$2" -ne 0 ]; then echo "FAIL: $1"; fail=1; fi
}
ok() { # desc, then the assertion as a command
  if "${@:2}"; then check "$1" 0; else check "$1" 1; fi
}

# ── fixture repo ────────────────────────────────────────────────────────────
mkdir -p "${TMP}/src"
cat > "${TMP}/src/store.py" <<'PY'
"""Fixture module."""


class Cart:
    def __init__(self, items):
        self.items = items

    def total(self):
        return sum(i.price for i in self.items)


def apply_discount(cart, pct):
    return cart.total() * (1 - pct)
PY
cat > "${TMP}/src/handler.go" <<'GO'
package main

type Order struct {
	ID string
}

func Process(o Order) error {
	if o.ID == "" {
		return nil
	}
	return nil
}
GO
printf 'binary\0payload\n' > "${TMP}/src/blob.bin"
printf '# notes\n\njust prose\n' > "${TMP}/README.md"
git -C "${TMP}" init -q
git -C "${TMP}" add -A
git -C "${TMP}" -c user.email=t@t -c user.name=t commit -qm init

IDX="${ROOT}/core/scripts/aidd-index.py"
RB="${ROOT}/core/scripts/aidd-read-block.py"
RL="${ROOT}/core/scripts/aidd-redact-log.py"
INDEX="${TMP}/.aidd/context/index.json"

for f in "${IDX}" "${RB}" "${RL}"; do
  [ -f "${f}" ] || { echo "FAIL: missing ${f}"; fail=1; }
done

# ── 1. Build: every tracked file indexed, symbols found, spans plausible ────
( cd "${TMP}" && python3 "${IDX}" --quiet )
ok "index.json created" test -f "${INDEX}"

py_q() { python3 -c "$1" "${INDEX}" "${@:2}"; }

ok "python class indexed with a span" py_q '
import json,sys
d=json.load(open(sys.argv[1]))["files"]["src/store.py"]["symbols"]
s=[x for x in d if x["name"]=="Cart"]
sys.exit(0 if s and s[0]["end"]>s[0]["start"] else 1)'

ok "python nested method indexed" py_q '
import json,sys
d=json.load(open(sys.argv[1]))["files"]["src/store.py"]["symbols"]
sys.exit(0 if any(x["name"]=="total" for x in d) else 1)'

ok "go func indexed by brace matching" py_q '
import json,sys
d=json.load(open(sys.argv[1]))["files"]["src/handler.go"]["symbols"]
s=[x for x in d if x["name"]=="Process"]
sys.exit(0 if s and s[0]["end"]>s[0]["start"] else 1)'

# Degradation is explicit, not silent: unknown/binary files still get an entry.
ok "binary file gets path+hash entry, no symbols" py_q '
import json,sys
e=json.load(open(sys.argv[1]))["files"]["src/blob.bin"]
sys.exit(0 if e["lang"]=="binary" and e["symbols"]==[] and e["hash"] else 1)'

ok "markdown degrades to path+hash only" py_q '
import json,sys
e=json.load(open(sys.argv[1]))["files"]["README.md"]
sys.exit(0 if e["symbols"]==[] and e["hash"] else 1)'

ok "hash algorithm recorded" py_q '
import json,sys
sys.exit(0 if json.load(open(sys.argv[1]))["hash_algo"]=="git-blob-sha1" else 1)'

# The hash must be the real git blob id — otherwise "unchanged" is a guess.
real="$(git -C "${TMP}" hash-object src/store.py)"
ok "hash equals git hash-object" py_q '
import json,sys
sys.exit(0 if json.load(open(sys.argv[1]))["files"]["src/store.py"]["hash"]==sys.argv[2] else 1)' "${real}"

# ── 2. Hash short-circuit: an unchanged rebuild reparses nothing ────────────
stats="$( cd "${TMP}" && python3 "${IDX}" --stats )"
parsed="$(printf '%s' "${stats}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["parsed"])')"
reused="$(printf '%s' "${stats}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["reused"])')"
ok "no-change rebuild reparses zero files" test "${parsed}" -eq 0
ok "no-change rebuild reuses every entry"   test "${reused}" -gt 0

# ── 3. Staleness is detected, and --check reports it without writing ────────
( cd "${TMP}" && python3 "${IDX}" --check >/dev/null )
check "clean tree reports no stale files" $?
printf '\n\ndef added_later():\n    return 42\n' >> "${TMP}/src/store.py"
( cd "${TMP}" && python3 "${IDX}" --check >/dev/null 2>&1 )
ok "mutated file reported stale (exit 3)" test $? -eq 3

# ── 4. read_block: correct span, targeted refresh, no stale serve ───────────
out="$( cd "${TMP}" && python3 "${RB}" src/store.py added_later 2>/dev/null )"
printf '%s' "${out}" | grep -q 'def added_later'
check "read_block finds a symbol added after indexing" $?
printf '%s' "${out}" | grep -q 'index refreshed'
check "read_block reports the targeted refresh" $?

out="$( cd "${TMP}" && python3 "${RB}" src/store.py total 2>/dev/null )"
printf '%s' "${out}" | grep -q 'def total'
check "read_block returns the requested symbol" $?
if printf '%s' "${out}" | grep -q 'class Cart'; then
  echo "FAIL: read_block leaked the enclosing class"; fail=1
fi

# The whole point: a span costs far less than the file it came from.
span_bytes="${#out}"
file_bytes="$(wc -c < "${TMP}/src/store.py" | tr -d ' ')"
ok "span is smaller than the whole file" test "${span_bytes}" -lt "${file_bytes}"

( cd "${TMP}" && python3 "${RB}" src/store.py no_such_symbol >/dev/null 2>&1 )
ok "unknown symbol exits 5, never prints a wrong span" test $? -eq 5

( cd "${TMP}" && python3 "${RB}" src/store.py --line 6 2>/dev/null ) | grep -q 'Cart\|__init__'
check "read_block --line resolves the enclosing symbol" $?

( cd "${TMP}" && python3 "${RB}" src/store.py --list 2>/dev/null ) | grep -q 'Cart'
check "read_block --list enumerates symbols" $?

# ── 5. Redaction: reduces hard, but never eats the error ────────────────────
{
  echo "platform darwin -- Python 3.11.0, pytest-7.4.0"
  echo "rootdir: /some/very/long/absolute/path"
  i=0; while [ "${i}" -lt 400 ]; do echo "Requirement already satisfied: dep-${i}"; i=$((i + 1)); done
  echo ">       assert cart.total() == 90"
  echo "E       AssertionError: assert 100 == 90"
  echo "tests/test_cart.py:42: AssertionError"
  i=0; while [ "${i}" -lt 300 ]; do echo "2026-08-06T11:22:33Z DEBUG cache warm 12.4ms"; i=$((i + 1)); done
} > "${TMP}/raw.log"

red="$(python3 "${RL}" "${TMP}/raw.log" --max-lines 30)"
printf '%s' "${red}" | grep -qF 'AssertionError'
check "redaction preserves the error type" $?
printf '%s' "${red}" | grep -qF 'assert 100 == 90'
check "redaction preserves the failing assertion" $?
printf '%s' "${red}" | grep -qF 'tests/test_cart.py:42'
check "redaction preserves the failing file:line" $?
printf '%s' "${red}" | grep -q 'pytest'
check "redaction identifies the runner" $?
printf '%s' "${red}" | grep -q '(x[0-9][0-9]*)'
check "redaction counts collapsed duplicates" $?

raw_lines="$(wc -l < "${TMP}/raw.log" | tr -d ' ')"
kept_lines="$(printf '%s\n' "${red}" | wc -l | tr -d ' ')"
ok "redaction reduces the log substantially" test "${kept_lines}" -lt $((raw_lines / 10))

# An unrecognized format must be labelled, never silently emptied.
printf 'zork frobnicated the widget\nzork frobnicated harder\n' > "${TMP}/weird.log"
weird="$(python3 "${RL}" "${TMP}/weird.log")"
printf '%s' "${weird}" | grep -q 'runner: unknown'
check "unknown format is labelled" $?
printf '%s' "${weird}" | grep -q 'TRUNCATED, not filtered'
check "unknown format warns it is truncated" $?

# Structured output stays machine-readable for the ledger.
python3 "${RL}" "${TMP}/raw.log" --json | python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d["runner"]=="pytest", d["runner"]
assert "AssertionError" in d["error_types"]
assert any("test_cart.py:42" in loc for loc in d["locations"])
assert 0 < d["reduction_ratio"] < 1
'
check "redaction --json carries runner, errors, locations, ratio" $?

exit "${fail}"
