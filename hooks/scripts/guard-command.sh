#!/usr/bin/env bash
# PreToolUse(Skill|SlashCommand|Task): enforce the command contract.
# 1. A /aidd:<name> with no row in the command manifest is DENIED (exit 2) with the
#    manifest's nearest match — unknown commands are rejected, never guessed.
# 2. An aidd-* skill is ALLOWED, with a one-line note that skills are not commands and
#    that the playbook the manifest names must be loaded before any reasoning.
# Canonical rules: protocol/command-contract.md. Manifest: scripts/aidd-commands.txt.
# Degrades silently (exit 0) outside an AIDD repo, with no manifest, or on an unparseable
# payload — a guard must never break an unrelated session.
set -uo pipefail
payload="$(cat)"
[ -d ".aidd" ] || exit 0

manifest=""
for cand in ".aidd/framework/scripts/aidd-commands.txt" \
            "${CLAUDE_PLUGIN_ROOT:-/nonexistent}/core/scripts/aidd-commands.txt"; do
  if [ -f "${cand}" ]; then manifest="${cand}"; break; fi
done
[ -n "${manifest}" ] || exit 0

verdict="$(printf '%s' "${payload}" | python3 -c '
import json, re, sys

SKILLS = ("aidd-pipeline", "aidd-state", "aidd-gates", "aidd-supervision", "aidd-pr-review")
CONTRACT = "protocol/command-contract.md"

def norm(raw):
    name = str(raw).strip().lstrip("/")
    return name[5:] if name.startswith("aidd:") else name

cmds = {}
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        for row in fh:
            row = row.strip()
            if not row or row.startswith("#") or row.count("|") < 2:
                continue
            cols = row.split("|")
            cmds[norm(cols[0])] = cols[2].strip()
except OSError:
    sys.exit(0)
if not cmds:
    sys.exit(0)

try:
    payload = json.load(sys.stdin)
    tool_input = payload.get("tool_input")
    tool = str(payload.get("tool_name") or "")
    blob = json.dumps(tool_input if isinstance(tool_input, dict) else {}, default=str)
except Exception:
    sys.exit(0)

names = []
if tool == "Skill" and isinstance(tool_input, dict):
    invoked = norm(tool_input.get("skill") or tool_input.get("name") or "")
    if invoked.startswith("aidd") and ":" not in invoked:
        names.append(invoked)
names += re.findall(r"/aidd:([A-Za-z0-9][A-Za-z0-9_-]*)", blob)

def closest(name):
    best, top = "", 0
    for opt in sorted(cmds):
        score = 100 if (name in opt or opt in name) else 0
        shared = 0
        while shared < min(len(name), len(opt)) and name[shared] == opt[shared]:
            shared += 1
        score += shared * 10 + len(set(name) & set(opt))
        if score > top:
            best, top = opt, score
    return best if top >= 10 else ""

lines, seen = [], set()
for name in names:
    if name in seen:
        continue
    seen.add(name)
    if name in SKILLS:
        lines.append(
            "NOTE:" + name + " is a SKILL, not a command (no /aidd:" + name + " exists). "
            "Load the playbook the manifest binds to the command before reasoning (" + CONTRACT + ").")
    elif name not in cmds:
        # The observed failure mode: a skill name used as a command (/aidd:supervision
        # for the aidd-supervision skill). Say that, instead of a misleading near-match.
        skill_confusion = next((s for s in SKILLS if s == "aidd-" + name), "")
        if not skill_confusion and not any(c.startswith(name) for c in cmds):
            # Suffix confusion only when no real command starts with the typed name --
            # /aidd:review must still point at /aidd:review-pr, not at the pr-review skill.
            skill_confusion = next((s for s in SKILLS if s.endswith("-" + name)), "")
        if skill_confusion:
            tail = ("`" + skill_confusion + "` is a SKILL, not a command — there is no "
                    "/aidd:" + name + ". Load the skill by name, or run the phase command "
                    "the manifest binds to this work.")
        else:
            near = closest(name)
            tail = ("Closest supported command: /aidd:" + near + " (" + cmds[near] + ")."
                    if near else "No close match in the manifest.")
        lines.append(
            "DENY:/aidd:" + name + " is not an AIDD command. " + tail +
            " Only rows in scripts/aidd-commands.txt are commands — name the closest one and stop, "
            "do not invent a phase, gate, or agent flow (" + CONTRACT + ").")
print("\n".join(lines))
' "${manifest}" 2>/dev/null || true)"

deny=0
while IFS= read -r line; do
  case "${line}" in
    NOTE:*) printf 'AIDD: %s\n' "${line#NOTE:}" >&2 ;;
    DENY:*) printf 'Blocked: %s\n' "${line#DENY:}" >&2; deny=1 ;;
  esac
done <<<"${verdict}"

[ "${deny}" -eq 0 ] || exit 2
exit 0
