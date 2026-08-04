#!/usr/bin/env bash
# Plugin manifest integrity: JSON parses, versions in sync, wrappers reference real files.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
fail=0

python3 - <<'PY' || fail=1
import json, os, sys

errors = []
version = open('VERSION', encoding='utf-8').read().strip()

plugin = json.load(open('.claude-plugin/plugin.json', encoding='utf-8'))
market = json.load(open('.claude-plugin/marketplace.json', encoding='utf-8'))
hooks = json.load(open('hooks/hooks.json', encoding='utf-8'))

if plugin['version'] != version:
    errors.append(f"plugin.json version {plugin['version']} != VERSION {version}")
for p in market.get('plugins', []):
    if p.get('version') != version:
        errors.append(f"marketplace plugin version {p.get('version')} != VERSION {version}")
# commands/skills are declared as arrays of dir paths; agents + hooks/hooks.json
# are auto-discovered by Claude Code and must NOT be declared in the manifest.
for key in ('commands', 'skills'):
    val = plugin.get(key)
    if not isinstance(val, list) or not all(os.path.isdir(d) for d in val):
        errors.append(f"plugin.json {key} must be a list of existing dirs, got: {val}")
for forbidden in ('agents', 'hooks'):
    if forbidden in plugin:
        errors.append(f"plugin.json must not declare '{forbidden}' (auto-discovered)")
for auto in ('agents', 'hooks/hooks.json'):
    if not os.path.exists(auto):
        errors.append(f"auto-discovered path missing on disk: {auto}")

cmds = sorted(f for f in os.listdir('commands') if f.endswith('.md'))
if len(cmds) != 17:
    errors.append(f"expected 17 commands, found {len(cmds)}")
for f in cmds:
    text = open(f'commands/{f}', encoding='utf-8').read()
    if not text.startswith('---') or 'description:' not in text.split('---')[1]:
        errors.append(f"commands/{f}: missing description frontmatter")

agents = sorted(f for f in os.listdir('agents') if f.endswith('.md'))
if len(agents) != 25:
    errors.append(f"expected 25 agents, found {len(agents)}")
for f in agents:
    role = f.replace('aidd-', '').replace('.md', '')
    if not os.path.isfile(f'core/roles/{role}.md'):
        errors.append(f"agents/{f}: no matching core/roles/{role}.md")
    text = open(f'agents/{f}', encoding='utf-8').read()
    fm = text.split('---')[1]
    if 'name:' not in fm or 'description:' not in fm:
        errors.append(f"agents/{f}: incomplete frontmatter")
    if f'.aidd/framework/roles/{role}.md' not in text:
        errors.append(f"agents/{f}: does not point at its vendored role file")

for group in hooks['hooks'].values():
    for entry in group:
        for h in entry['hooks']:
            script = h['command'].split('"')[1].replace('${CLAUDE_PLUGIN_ROOT}/', '')
            if not os.path.isfile(script):
                errors.append(f"hooks.json references missing script: {script}")
            elif not os.access(script, os.X_OK):
                errors.append(f"hook script not executable: {script}")

skills = sorted(os.listdir('skills'))
if len(skills) != 4:
    errors.append(f"expected 4 skills, found {len(skills)}")
for s in skills:
    text = open(f'skills/{s}/SKILL.md', encoding='utf-8').read()
    fm = text.split('---')[1]
    if 'name:' not in fm or 'description:' not in fm:
        errors.append(f"skills/{s}: incomplete frontmatter")

if errors:
    print('\n'.join(errors))
    sys.exit(1)
print('manifest OK')
PY

exit "${fail}"
