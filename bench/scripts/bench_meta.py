#!/usr/bin/env python3
"""Frontmatter reader, validator, and lister for the bench corpus.

Usage:
  bench_meta.py --file <path> --field <key>
  bench_meta.py --file <path> --fields <k1,k2,...>   (tab-separated, one line)
  bench_meta.py --file <path> --helpers              (BENCH_REPO_ROOT paths it references)
  bench_meta.py --file <path> --json
  bench_meta.py --file <path> --validate task|defect
  bench_meta.py --list tasks|defects [--class C] [--offline] [--root DIR]

The frontmatter dialect is the same strict YAML subset the framework already relies on
(ADR 002 — no PyYAML anywhere): block style, `key: value` plain scalars, and `key: |`
block scalars dedented to their own minimum indentation. Nothing else is accepted, so a
task file that drifts into flow style or anchors fails validation instead of being
half-parsed.

Exit 0 on success, 1 on a validation failure (errors on stderr), 2 on a usage error.
"""

import os
import re
import sys

TASK_KEYS = [
    "id", "title", "repo", "commit", "verified", "class", "expected_rigor", "difficulty",
    "token_budget_hint", "setup", "intent", "pretest", "acceptance", "oracle", "notes",
]
DEFECT_KEYS = [
    "id", "target", "defect_class", "injection_mode", "visible_to", "injection",
    "why_ordinary_review_misses_it", "detection_signal", "grader",
]
CLASSES = ["bugfix", "feature", "refactor", "security", "migration", "docs"]
RIGORS = ["fast", "standard", "critical"]
DEFECT_CLASSES = [
    "auth-bypass", "tenant-leak", "off-by-one", "race", "silent-catch", "mocked-proof",
    "missing-ac-coverage", "perf-regression", "contract-break", "migration-data-loss",
    "secret-leak", "logic-inversion", "orphan-diff", "process-skip",
]
LAYERS = ["L1-review", "L1-tests", "L2-auditor", "L2-tally", "L2-debate", "L3-supervisor"]
INJECTION_MODES = ["command", "instruction"]
BLOCK_KEYS = {
    "setup", "pretest", "acceptance", "oracle", "notes", "injection",
    "why_ordinary_review_misses_it", "detection_signal", "grader",
}


def repo_root(explicit=None):
    if explicit:
        return os.path.abspath(explicit)
    return os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def parse_frontmatter(path):
    """Return (mapping, errors). Errors are structural, not semantic."""
    errors = []
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().split("\n")
    if not lines or lines[0].strip() != "---":
        return {}, [f"{path}: does not start with a '---' frontmatter fence"]
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end = i
            break
    if end is None:
        return {}, [f"{path}: frontmatter is never closed with '---'"]

    body = lines[1:end]
    data = {}
    i = 0
    while i < len(body):
        line = body[i]
        if not line.strip():
            i += 1
            continue
        match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):\s?(.*)$", line)
        if not match:
            errors.append(f"{path}: line {i + 2} is not 'key: value': {line!r}")
            i += 1
            continue
        key, value = match.group(1), match.group(2)
        if value.strip() in ("|", ">", "|-", ">-"):
            block, i = [], i + 1
            while i < len(body) and (not body[i].strip() or body[i].startswith((" ", "\t"))):
                block.append(body[i])
                i += 1
            indents = [len(b) - len(b.lstrip()) for b in block if b.strip()]
            pad = min(indents) if indents else 0
            data[key] = "\n".join(b[pad:] if b.strip() else "" for b in block).strip("\n")
        else:
            data[key] = value.strip()
            i += 1
    return data, errors


def check_common(path, data, keys, prefix):
    errors = []
    stem = os.path.basename(path)[: -len(".md")]
    for key in keys:
        if key not in data:
            errors.append(f"{path}: missing required key '{key}'")
        elif not str(data[key]).strip():
            errors.append(f"{path}: key '{key}' is empty")
    if data.get("id") and data["id"] != stem:
        errors.append(f"{path}: id {data['id']!r} does not match the filename stem {stem!r}")
    if data.get("id") and not re.match(rf"^{prefix}-\d{{3}}-[a-z0-9][a-z0-9-]*$", data["id"]):
        errors.append(f"{path}: id {data['id']!r} is not {prefix}-NNN-slug")
    for key in keys:
        if key in BLOCK_KEYS and key in data and len(data[key].strip()) < 10:
            errors.append(f"{path}: block '{key}' is too short to be a real {key}")
    return errors


def validate_task(path, data, root):
    errors = check_common(path, data, TASK_KEYS, "T")
    if data.get("class") not in CLASSES:
        errors.append(f"{path}: class {data.get('class')!r} not in {CLASSES}")
    if data.get("expected_rigor") not in RIGORS:
        errors.append(f"{path}: expected_rigor {data.get('expected_rigor')!r} not in {RIGORS}")
    if data.get("verified") not in ("true", "false"):
        errors.append(f"{path}: verified must be true or false, got {data.get('verified')!r}")
    for key, lo, hi in (("difficulty", 1, 5), ("token_budget_hint", 1, 10_000_000)):
        raw = data.get(key, "")
        if not re.match(r"^\d+$", raw) or not lo <= int(raw) <= hi:
            errors.append(f"{path}: {key} must be an integer in {lo}..{hi}, got {raw!r}")
    repo = data.get("repo", "")
    if repo.startswith("local:"):
        target = os.path.join(root, repo[len("local:"):])
        if not os.path.isdir(target):
            errors.append(f"{path}: offline fixture {repo} does not exist on disk")
        if data.get("commit") != "local":
            errors.append(f"{path}: a local: repo must pin commit 'local'")
    elif repo.startswith("https://"):
        if not re.match(r"^[0-9a-f]{40}$", data.get("commit", "")):
            errors.append(f"{path}: commit must be a 40-hex SHA for a remote repo")
    else:
        errors.append(f"{path}: repo must be 'local:...' or an https URL, got {repo!r}")
    intent = data.get("intent", "")
    if "\n" in intent:
        errors.append(f"{path}: intent must be a single line (it is handed to every arm verbatim)")
    if len(intent) < 20:
        errors.append(f"{path}: intent is too short to be an instruction")
    return errors


def validate_defect(path, data, root):
    errors = check_common(path, data, DEFECT_KEYS, "D")
    if data.get("defect_class") not in DEFECT_CLASSES:
        errors.append(f"{path}: defect_class {data.get('defect_class')!r} not in {DEFECT_CLASSES}")
    if data.get("injection_mode") not in INJECTION_MODES:
        errors.append(f"{path}: injection_mode must be one of {INJECTION_MODES}")
    tokens = [t.strip() for t in data.get("visible_to", "").split(",") if t.strip()]
    if not tokens:
        errors.append(f"{path}: visible_to is empty")
    for token in tokens:
        if token not in LAYERS:
            errors.append(f"{path}: visible_to token {token!r} not in {LAYERS}")
    why = data.get("why_ordinary_review_misses_it", "")
    if len(why) < 120:
        errors.append(f"{path}: why_ordinary_review_misses_it must be a real argument, not a phrase")
    target = data.get("target", "")
    if target.startswith("local:"):
        if not os.path.isdir(os.path.join(root, target[len("local:"):])):
            errors.append(f"{path}: target fixture {target} does not exist")
    elif not os.path.isfile(os.path.join(root, "bench", "tasks", f"{target}.md")):
        errors.append(f"{path}: target {target!r} resolves to no task and no fixture")
    return errors


def listing(kind, root, want_class=None, offline=False):
    directory = os.path.join(root, "bench", "tasks" if kind == "tasks" else "defects")
    rows = []
    for name in sorted(os.listdir(directory)):
        if not name.endswith(".md"):
            continue
        path = os.path.join(directory, name)
        data, errors = parse_frontmatter(path)
        if errors:
            print("\n".join(errors), file=sys.stderr)
            return None
        if kind == "tasks":
            if want_class and data.get("class") != want_class:
                continue
            if offline and not data.get("repo", "").startswith("local:"):
                continue
            rows.append("\t".join([
                data.get("id", "?"), os.path.relpath(path, root), data.get("class", "?"),
                data.get("expected_rigor", "?"), data.get("difficulty", "?"),
                data.get("repo", "?"), data.get("token_budget_hint", "?"),
            ]))
        else:
            rows.append("\t".join([
                data.get("id", "?"), os.path.relpath(path, root), data.get("defect_class", "?"),
                data.get("injection_mode", "?"), data.get("visible_to", "?"),
                data.get("target", "?"),
            ]))
    return rows


def json_dump(data):
    import json
    return json.dumps(data, indent=2, sort_keys=True)


def main(argv):
    args = argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if args else 2
    opts = {}
    i = 0
    while i < len(args):
        if args[i] in ("--file", "--field", "--fields", "--validate", "--list", "--class", "--root"):
            if i + 1 >= len(args):
                print(f"{args[i]} needs a value", file=sys.stderr)
                return 2
            opts[args[i].lstrip("-")] = args[i + 1]
            i += 2
        elif args[i] in ("--json", "--offline", "--helpers"):
            opts[args[i].lstrip("-")] = True
            i += 1
        else:
            print(f"unknown argument {args[i]!r}", file=sys.stderr)
            return 2
    root = repo_root(opts.get("root"))

    if "list" in opts:
        if opts["list"] not in ("tasks", "defects"):
            print("--list takes 'tasks' or 'defects'", file=sys.stderr)
            return 2
        rows = listing(opts["list"], root, opts.get("class"), bool(opts.get("offline")))
        if rows is None:
            return 1
        print("\n".join(rows))
        return 0

    path = opts.get("file")
    if not path:
        print("--file is required outside --list", file=sys.stderr)
        return 2
    if not os.path.isfile(path):
        print(f"{path}: no such file", file=sys.stderr)
        return 2
    data, errors = parse_frontmatter(path)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1

    if "validate" in opts:
        kind = opts["validate"]
        if kind == "task":
            errors = validate_task(path, data, root)
        elif kind == "defect":
            errors = validate_defect(path, data, root)
        else:
            print("--validate takes 'task' or 'defect'", file=sys.stderr)
            return 2
        if errors:
            print("\n".join(errors), file=sys.stderr)
            return 1
        print(f"OK {data['id']}")
        return 0

    if opts.get("json"):
        print(json_dump(data))
        return 0

    if opts.get("helpers"):
        # Every ${BENCH_REPO_ROOT}-relative path the executable blocks reference. The dry
        # run checks each one exists, so a task cannot silently point at a missing grader.
        found = set()
        for key in ("setup", "pretest", "oracle", "injection", "grader"):
            for hit in re.findall(r"\$\{BENCH_REPO_ROOT\}/([A-Za-z0-9_./-]+)", data.get(key, "")):
                found.add(hit)
        print("\n".join(sorted(found)))
        return 0

    if "fields" in opts:
        wanted = [f.strip() for f in opts["fields"].split(",") if f.strip()]
        missing = [f for f in wanted if f not in data]
        if missing:
            print(f"{path}: no key(s) {missing}", file=sys.stderr)
            return 1
        print("\t".join(data[f].replace("\t", " ").replace("\n", " ") for f in wanted))
        return 0

    field = opts.get("field")
    if not field:
        print("give --field, --json, or --validate", file=sys.stderr)
        return 2
    if field not in data:
        print(f"{path}: no key {field!r}", file=sys.stderr)
        return 1
    print(data[field])
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
