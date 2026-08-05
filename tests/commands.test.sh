#!/usr/bin/env bash
# Command contract: the manifest is 1:1 with commands/, the contract doc stays in sync with
# it, and guard-command.sh denies an unknown /aidd: command while allowing a real one.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd)"
fail=0
MANIFEST=core/scripts/aidd-commands.txt
CONTRACT=core/protocol/command-contract.md
GUARD=hooks/scripts/guard-command.sh

[ -f "${MANIFEST}" ] || { echo "missing command manifest: ${MANIFEST}"; exit 1; }
[ -f "${CONTRACT}" ] || { echo "missing contract: ${CONTRACT}"; exit 1; }
[ -x "${GUARD}" ]    || { echo "guard not executable: ${GUARD}"; fail=1; }

# ── manifest ↔ commands/ ↔ contract binding table
python3 - <<'PY' || fail=1
import os, re, sys

errors = []
rows, seen = {}, []
with open('core/scripts/aidd-commands.txt', encoding='utf-8') as fh:
    for n, raw in enumerate(fh, 1):
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        cols = line.split('|')
        if len(cols) != 3 or not all(c.strip() for c in cols):
            errors.append(f'manifest line {n}: expected <command>|<path>|<purpose>, got {line!r}')
            continue
        cmd, path, purpose = (c.strip() for c in cols)
        if not cmd.startswith('/aidd:'):
            errors.append(f'manifest line {n}: command must be /aidd:<name>, got {cmd!r}')
            continue
        name = cmd[len('/aidd:'):]
        if name in rows:
            errors.append(f'manifest: duplicate row for {cmd}')
        rows[name] = (path, purpose)
        seen.append(name)

files = sorted(f[:-3] for f in os.listdir('commands') if f.endswith('.md'))
for name in files:
    if name not in rows:
        errors.append(f'commands/{name}.md has no manifest row')
for name in sorted(rows):
    if name not in files:
        errors.append(f'phantom manifest row /aidd:{name} — no commands/{name}.md')
if seen != sorted(seen):
    errors.append('manifest rows must be sorted by command name')

# Every bound path must resolve (vendored .aidd/framework/X == repo core/X).
for name, (path, _purpose) in sorted(rows.items()):
    target = 'core/' + path[len('.aidd/framework/'):] if path.startswith('.aidd/framework/') else path
    if not os.path.exists(target):
        errors.append(f'/aidd:{name} binds to a missing file: {path} (-> {target})')

# The command file must actually name the path the manifest binds it to.
for name, (path, _purpose) in sorted(rows.items()):
    body = open(f'commands/{name}.md', encoding='utf-8').read()
    if path not in body:
        errors.append(f'commands/{name}.md does not reference its manifest path {path}')

# Contract binding table must match the manifest exactly, both directions.
contract = open('core/protocol/command-contract.md', encoding='utf-8').read()
bindings = re.findall(r'^\|\s*`(/aidd:[a-z-]+)`\s*\|\s*`([^`]+)`\s*\|', contract, re.M)
table = dict(bindings)
if len(bindings) != len(table):
    errors.append('contract binding table has duplicate rows')
if len(bindings) != len(rows):
    errors.append(f'contract binding table has {len(bindings)} rows, manifest has {len(rows)}')
for name, (path, _purpose) in sorted(rows.items()):
    key = f'/aidd:{name}'
    if key not in table:
        errors.append(f'contract binding table missing {key}')
    elif table[key] != path:
        errors.append(f'contract binds {key} to {table[key]!r}, manifest says {path!r}')
for key in sorted(table):
    if key[len('/aidd:'):] not in rows:
        errors.append(f'contract binding table has phantom row {key}')

# All four skills must be named as non-commands.
for skill in ('aidd-pipeline', 'aidd-state', 'aidd-gates', 'aidd-supervision'):
    if skill not in contract:
        errors.append(f'contract does not name the skill {skill}')
    if f'/aidd:{skill}' not in contract:
        errors.append(f'contract does not forbid /aidd:{skill} explicitly')
for phrase in ('Skills are not commands', 'Load before reason', 'improvised phase logic',
               'supervision violation', 'nearest match'):
    if phrase not in contract:
        errors.append(f'contract missing required rule text: {phrase!r}')

if errors:
    print('\n'.join(errors))
    sys.exit(1)
print(f'command manifest OK ({len(rows)} commands)')
PY

# ── guard shape: no set -e misuse, degrades instead of aborting
grep -qE '^set -uo pipefail$' "${GUARD}" || { echo "guard must use 'set -uo pipefail'"; fail=1; }
grep -qE '^set -e' "${GUARD}" && { echo "guard must not 'set -e' (it degrades, never aborts)"; fail=1; }
grep -q 'aidd-commands.txt' "${GUARD}" || { echo "guard does not read the manifest"; fail=1; }
grep -q 'guard-command.sh' hooks/hooks.json || { echo "hooks.json missing guard-command.sh"; fail=1; }

# ── guard behavior, driven with printf'd JSON payloads on stdin
TMP="tests/tmp/commands-$$"
mkdir -p "${TMP}/.aidd/framework/scripts"
cleanup() { python3 -c "import shutil; shutil.rmtree('${ROOT}/${TMP}', ignore_errors=True)"; }
trap cleanup EXIT
cp "${MANIFEST}" "${TMP}/.aidd/framework/scripts/"

slash() { printf '{"tool_name":"SlashCommand","tool_input":{"command":"/aidd:%s"}}' "$1"; }
skill()  { printf '{"tool_name":"Skill","tool_input":{"skill":"aidd:%s"}}' "$1"; }

# outside an AIDD repo (no .aidd/) -> silent exit 0 even for a bogus command
NOAIDD="$(mktemp -d)"
( cd "${NOAIDD}" && slash "not-a-command" | bash "${ROOT}/${GUARD}" >/dev/null 2>&1 )
[ $? -eq 0 ] || { echo "guard fired outside an AIDD repo"; fail=1; }
rm -rf "${NOAIDD}"

(
  cd "${TMP}" || exit 1
  code=0
  # real command -> allowed
  slash "qa" | bash "${ROOT}/${GUARD}" >/dev/null 2>&1
  [ $? -eq 0 ] || { echo "guard denied the real command /aidd:qa"; code=1; }
  # unknown command -> denied (exit 2) naming the nearest manifest match
  out="$(slash "qa-run" | bash "${ROOT}/${GUARD}" 2>&1)"
  [ $? -eq 2 ] || { echo "guard allowed the unknown command /aidd:qa-run"; code=1; }
  echo "${out}" | grep -q '/aidd:qa' || { echo "deny message lacks the nearest match: ${out}"; code=1; }
  # a /aidd: reference inside any payload (a Task prompt) is judged too
  printf '{"tool_name":"Task","tool_input":{"prompt":"orchestrate /aidd:qa-phase now"}}' \
    | bash "${ROOT}/${GUARD}" >/dev/null 2>&1
  [ $? -eq 2 ] || { echo "guard ignored an unknown /aidd: command in a Task payload"; code=1; }
  # a real skill -> allowed, with the skills-are-not-commands note on stderr
  note="$(skill "aidd-supervision" | bash "${ROOT}/${GUARD}" 2>&1)"
  [ $? -eq 0 ] || { echo "guard denied the legitimate skill aidd-supervision"; code=1; }
  echo "${note}" | grep -qi 'not a command' \
    || { echo "guard did not note that skills are not commands: ${note}"; code=1; }
  # an unrelated (non-AIDD) skill is none of the guard's business
  printf '{"tool_name":"Skill","tool_input":{"skill":"dataviz"}}' \
    | bash "${ROOT}/${GUARD}" >/dev/null 2>&1
  [ $? -eq 0 ] || { echo "guard fired on an unrelated skill"; code=1; }
  # unparseable payload -> silent exit 0
  printf 'not json at all' | bash "${ROOT}/${GUARD}" >/dev/null 2>&1
  [ $? -eq 0 ] || { echo "guard broke on an unparseable payload"; code=1; }
  # manifest missing (stale vendored framework) -> silent exit 0
  mv .aidd/framework/scripts/aidd-commands.txt .aidd/framework/scripts/away.txt
  slash "not-a-command" \
    | CLAUDE_PLUGIN_ROOT=/nonexistent bash "${ROOT}/${GUARD}" >/dev/null 2>&1
  [ $? -eq 0 ] || { echo "guard fired with no manifest present"; code=1; }
  exit "${code}"
) || fail=1

exit "${fail}"
