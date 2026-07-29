#!/usr/bin/env bash
# Sync VERSION into every manifest that embeds it.
# Usage: bump-version.sh [X.Y.Z]  (no arg: re-sync current VERSION)
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "${1:-}" != "" ]; then echo "$1" > VERSION; fi
V="$(tr -d '[:space:]' < VERSION)"
python3 - "$V" <<'PY'
import json, re, sys
v = sys.argv[1]
for manifest in ('.claude-plugin/plugin.json', '.claude-plugin/marketplace.json'):
    try:
        with open(manifest, encoding='utf-8') as fh:
            data = json.load(fh)
    except FileNotFoundError:
        continue
    if 'version' in data:
        data['version'] = v
    for plugin in data.get('plugins', []):
        plugin['version'] = v
    with open(manifest, 'w', encoding='utf-8') as fh:
        json.dump(data, fh, indent=2)
        fh.write('\n')
try:
    src = open('install.sh', encoding='utf-8').read()
    src = re.sub(r'^AIDD_VERSION=.*$', f'AIDD_VERSION="{v}"', src, count=1, flags=re.M)
    open('install.sh', 'w', encoding='utf-8').write(src)
except FileNotFoundError:
    pass
print(f'version synced: {v}')
PY
