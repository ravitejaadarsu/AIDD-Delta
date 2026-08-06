#!/usr/bin/env bash
# Cross-reference integrity: every repo path referenced in markdown must exist.
# .aidd/framework/X references map to core/X (the vendored layout).
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import os, re, sys

ROOT = os.getcwd()
ENFORCED_TOPS = {"core", "commands", "agents", "skills", "hooks", "docs", "scripts",
                 "tests", ".github", "templates", "prompts", "roles", "protocol",
                 "playbooks", "schemas"}
SKIP_DIRS = {".git", "node_modules", "tests/tmp", "changes"}
REF_RE = re.compile(r'(?:\.\./|\.aidd/framework/)?(?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]+\.[A-Za-z0-9]+')

def md_files():
    for dirpath, dirnames, filenames in os.walk(ROOT):
        rel = os.path.relpath(dirpath, ROOT)
        dirnames[:] = [d for d in dirnames if d not in {".git", "node_modules", "tmp"}]
        for f in filenames:
            if f.endswith(".md") and not any(x in os.path.join(dirpath, f) for x in ("tests/fixtures", "tests/scenarios", "docs/plans", "docs/specs")):
                yield os.path.join(dirpath, f)

errors = []
for md in md_files():
    reldir = os.path.dirname(os.path.relpath(md, ROOT))
    text = open(md, encoding="utf-8").read()
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    for raw in REF_RE.findall(text):
        if any(c in raw for c in "<>*{}$"):
            continue
        ref = raw
        if ref.startswith(".aidd/framework/"):
            ref = "core/" + ref[len(".aidd/framework/"):]
        elif ref.startswith(".aidd/"):
            continue
        candidates = []
        if ref.startswith("../"):
            candidates.append(os.path.normpath(os.path.join(reldir, ref)))
        else:
            candidates += [ref, os.path.join(reldir, ref), os.path.join("core", ref)]
        top = os.path.normpath(candidates[0]).split(os.sep)[0]
        if not ref.startswith("../") and ref.split("/")[0] not in ENFORCED_TOPS:
            continue
        if not any(os.path.exists(os.path.join(ROOT, c)) for c in candidates):
            errors.append(f"{os.path.relpath(md, ROOT)}: broken ref '{raw}'")

if errors:
    print("\n".join(sorted(set(errors))))
    sys.exit(1)
print("refs OK")
PY
