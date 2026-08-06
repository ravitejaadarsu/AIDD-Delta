#!/usr/bin/env bash
# Benchmark harness conformance: the corpus, the defect catalogue, and the scripts.
# Offline, fast, no API key. The assertions here are independent of bench_meta.py's own
# validator on purpose — a schema whose only checker is the code that produced it is not
# checked at all.
# NOTE: a comment must not begin with the word "shellcheck" — it parses as a directive.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
fail=0

check() { # desc, exit-code
  if [ "$2" -ne 0 ]; then echo "FAIL: $1"; fail=1; fi
}

# 1-6. Schema, floors, enums, and cross-references, in one pass over both directories.
python3 - <<'PY' || fail=1
import os
import re
import sys

TASK_KEYS = ["id", "title", "repo", "commit", "verified", "class", "expected_rigor",
             "difficulty", "token_budget_hint", "setup", "intent", "pretest", "acceptance",
             "oracle", "notes"]
DEFECT_KEYS = ["id", "target", "defect_class", "injection_mode", "visible_to", "injection",
               "why_ordinary_review_misses_it", "detection_signal", "grader"]
CLASSES = {"bugfix", "feature", "refactor", "security", "migration", "docs"}
RIGORS = {"fast", "standard", "critical"}
DEFECT_CLASSES = {"auth-bypass", "tenant-leak", "off-by-one", "race", "silent-catch",
                  "mocked-proof", "missing-ac-coverage", "perf-regression", "contract-break",
                  "migration-data-loss", "secret-leak", "logic-inversion", "orphan-diff",
                  "process-skip"}
LAYERS = {"L1-review", "L1-tests", "L2-auditor", "L2-tally", "L2-debate", "L3-supervisor"}
MODES = {"command", "instruction"}
LAYER2_JUSTIFYING = {"mocked-proof", "missing-ac-coverage", "orphan-diff"}

errors = []


def frontmatter(path):
    lines = open(path, encoding="utf-8").read().split("\n")
    if lines[0].strip() != "---":
        errors.append(f"{path}: no frontmatter fence")
        return {}
    end = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
    if end is None:
        errors.append(f"{path}: unterminated frontmatter")
        return {}
    data, body, i = {}, lines[1:end], 0
    while i < len(body):
        line = body[i]
        if not line.strip():
            i += 1
            continue
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):\s?(.*)$", line)
        if not m:
            errors.append(f"{path}: line {i + 2} is not 'key: value'")
            i += 1
            continue
        key, val = m.group(1), m.group(2)
        if val.strip() in ("|", ">"):
            block, i = [], i + 1
            while i < len(body) and (not body[i].strip() or body[i].startswith((" ", "\t"))):
                block.append(body[i])
                i += 1
            pad = min([len(b) - len(b.lstrip()) for b in block if b.strip()] or [0])
            data[key] = "\n".join(b[pad:] if b.strip() else "" for b in block).strip("\n")
        else:
            data[key] = val.strip()
            i += 1
    return data


tasks, seen_ids = {}, set()
for name in sorted(os.listdir("bench/tasks")):
    if not name.endswith(".md"):
        continue
    path = f"bench/tasks/{name}"
    data = frontmatter(path)
    tasks[path] = data
    for key in TASK_KEYS:
        if key not in data or not str(data[key]).strip():
            errors.append(f"{path}: missing or empty required key {key!r}")
    stem = name[:-3]
    if data.get("id") != stem:
        errors.append(f"{path}: id {data.get('id')!r} != filename stem {stem!r}")
    if data.get("id") in seen_ids:
        errors.append(f"{path}: duplicate id {data.get('id')!r}")
    seen_ids.add(data.get("id"))
    if data.get("class") not in CLASSES:
        errors.append(f"{path}: class {data.get('class')!r} is not a valid enum value")
    if data.get("expected_rigor") not in RIGORS:
        errors.append(f"{path}: expected_rigor {data.get('expected_rigor')!r} is invalid")
    if data.get("verified") not in ("true", "false"):
        errors.append(f"{path}: verified must be true or false")
    if not re.match(r"^[1-5]$", data.get("difficulty", "")):
        errors.append(f"{path}: difficulty must be 1..5, got {data.get('difficulty')!r}")
    if not re.match(r"^\d+$", data.get("token_budget_hint", "")):
        errors.append(f"{path}: token_budget_hint must be an integer")
    repo = data.get("repo", "")
    if repo.startswith("local:"):
        if not os.path.isdir(repo[len("local:"):]):
            errors.append(f"{path}: offline fixture {repo} is not on disk")
        if data.get("commit") != "local":
            errors.append(f"{path}: a local: repo must pin commit 'local'")
    elif repo.startswith("https://"):
        if not re.match(r"^[0-9a-f]{40}$", data.get("commit", "")):
            errors.append(f"{path}: remote repo must pin a 40-hex SHA")
    else:
        errors.append(f"{path}: repo must be local: or https://, got {repo!r}")
    if "\n" in data.get("intent", ""):
        errors.append(f"{path}: intent must be one line (it is handed to every arm verbatim)")

if len(tasks) < 24:
    errors.append(f"corpus floor: need >=24 tasks, found {len(tasks)}")
by_class = {}
for path, data in tasks.items():
    by_class.setdefault(data.get("class"), []).append(path)
for klass in sorted(CLASSES):
    if len(by_class.get(klass, [])) < 4:
        errors.append(f"corpus floor: class {klass} has {len(by_class.get(klass, []))} tasks, need >=4")
offline = [p for p, d in tasks.items() if d.get("repo", "").startswith("local:")]
if len(offline) < 6:
    errors.append(f"corpus floor: need >=6 offline tasks, found {len(offline)}")

defects, defect_ids, defect_classes = {}, set(), set()
for name in sorted(os.listdir("bench/defects")):
    if not name.endswith(".md"):
        continue
    path = f"bench/defects/{name}"
    data = frontmatter(path)
    defects[path] = data
    for key in DEFECT_KEYS:
        if key not in data or not str(data[key]).strip():
            errors.append(f"{path}: missing or empty required key {key!r}")
    stem = name[:-3]
    if data.get("id") != stem:
        errors.append(f"{path}: id {data.get('id')!r} != filename stem {stem!r}")
    if data.get("id") in defect_ids:
        errors.append(f"{path}: duplicate id {data.get('id')!r}")
    defect_ids.add(data.get("id"))
    if data.get("defect_class") not in DEFECT_CLASSES:
        errors.append(f"{path}: defect_class {data.get('defect_class')!r} is invalid")
    defect_classes.add(data.get("defect_class"))
    if data.get("injection_mode") not in MODES:
        errors.append(f"{path}: injection_mode {data.get('injection_mode')!r} is invalid")
    tokens = [t.strip() for t in data.get("visible_to", "").split(",") if t.strip()]
    if not tokens:
        errors.append(f"{path}: visible_to is empty")
    for token in tokens:
        if token not in LAYERS:
            errors.append(f"{path}: visible_to token {token!r} is invalid")
    why = data.get("why_ordinary_review_misses_it", "")
    if len(why.strip()) < 120:
        errors.append(f"{path}: why_ordinary_review_misses_it must be a real argument")
    target = data.get("target", "")
    if target.startswith("local:"):
        if not os.path.isdir(target[len("local:"):]):
            errors.append(f"{path}: target fixture {target} does not exist")
    elif not os.path.isfile(f"bench/tasks/{target}.md"):
        errors.append(f"{path}: target {target!r} resolves to no task and no fixture")

if len(defects) < 12:
    errors.append(f"catalogue floor: need >=12 defects, found {len(defects)}")
for klass in sorted(LAYER2_JUSTIFYING):
    if klass not in defect_classes:
        errors.append(f"catalogue floor: the Layer-2-justifying class {klass!r} is absent")
missing_classes = DEFECT_CLASSES - defect_classes
if missing_classes:
    errors.append(f"catalogue floor: defect classes with no instance: {sorted(missing_classes)}")

if errors:
    print("\n".join(errors))
    sys.exit(1)
print(f"corpus OK: {len(tasks)} tasks ({len(offline)} offline), {len(defects)} defects, "
      f"{len(defect_classes)} defect classes covered")
PY

# 7. The offline dry run validates the whole offline corpus and lists every offline task.
dry_out="$(bash bench/scripts/bench-run.sh --dry-run --offline 2>&1)"
check "bench-run.sh --dry-run --offline exits 0" $?
offline_ids="$(python3 bench/scripts/bench_meta.py --list tasks --offline | cut -f1)"
while read -r id; do
  [ -n "${id}" ] || continue
  case "${dry_out}" in
    *"PLAN ${id} "*) ;;
    *) echo "FAIL: dry run did not plan offline task ${id}"; fail=1 ;;
  esac
done <<<"${offline_ids}"
case "${dry_out}" in
  *"dry-run OK"*) ;;
  *) echo "FAIL: dry run did not report OK"; fail=1 ;;
esac

# 8. Every script answers --help without a model, a network, or arguments.
for script in bench-run bench-grade bench-inject bench-report; do
  bash "bench/scripts/${script}.sh" --help >/dev/null 2>&1
  check "bench/scripts/${script}.sh --help exits 0" $?
done

# 9. The results template carries the `not measured` convention and every report marker.
grep -q 'not measured' bench/results/TEMPLATE.md
check "results TEMPLATE.md states the 'not measured' convention" $?
for marker in RUN-META PER-TASK DEFECTS-BY-LAYER DERIVED EVIDENCE; do
  grep -q "BENCH:${marker}" bench/results/TEMPLATE.md
  check "TEMPLATE.md carries the ${marker} marker" $?
done

# 10. No measured numbers ship: results holds only the template and the placeholder.
stray="$(find bench/results -type f ! -name 'TEMPLATE.md' ! -name '.gitkeep' | head -5)"
if [ -z "${stray}" ]; then stray_rc=0; else stray_rc=1; fi
check "bench/results ships no run output (found: ${stray:-none})" "${stray_rc}"

# 11. Defect injections and task oracles reference helpers that exist on disk.
missing_helpers="$(grep -rhoE '\$\{BENCH_REPO_ROOT\}/[A-Za-z0-9_./-]+' bench/tasks bench/defects |
  sed 's|${BENCH_REPO_ROOT}/||' | sort -u | while read -r p; do [ -e "${p}" ] || echo "${p}"; done)"
if [ -z "${missing_helpers}" ]; then helper_rc=0; else helper_rc=1; fi
check "every referenced bench helper exists (missing: ${missing_helpers:-none})" "${helper_rc}"

# 12. The graders themselves run: each oracle helper answers --help.
for helper in bench/fixtures/oracles/todo_api.py bench/fixtures/oracles/web_page.py \
              bench/fixtures/oracles/max_func_lines.py; do
  python3 "${helper}" --help >/dev/null 2>&1
  check "${helper} --help exits 0" $?
done

# 13. bench-patch.py refuses an anchor that is absent or ambiguous, so a drifted tree
#     fails loudly instead of half-applying an injection.
TMP="$(mktemp -d)"
printf 'alpha\nbeta\nalpha\n' >"${TMP}/f.txt"
python3 bench/scripts/bench-patch.py "${TMP}/f.txt" --expect "gamma" --replace "x" >/dev/null 2>&1
missing_rc=$?
python3 bench/scripts/bench-patch.py "${TMP}/f.txt" --expect "alpha" --replace "x" >/dev/null 2>&1
ambiguous_rc=$?
[ "${missing_rc}" -eq 3 ]
check "bench-patch rejects an absent anchor with exit 3" $?
[ "${ambiguous_rc}" -eq 3 ]
check "bench-patch rejects an ambiguous anchor with exit 3" $?
rm -rf "${TMP}"

# 14. Lint the bench scripts when a linter is available (tests/run.sh lints only its own set).
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -S warning bench/scripts/*.sh
  check "bench/scripts/*.sh are shellcheck-clean at -S warning" $?
fi

# 15. The context-cost arm: measures bytes, and never launders them into tokens.
#     This arm is the one a reader is most likely to over-read, so the assertions
#     cover what it refuses to claim as much as what it computes.
CTX_TMP="$(mktemp -d)"
mkdir -p "${CTX_TMP}/src"
cat > "${CTX_TMP}/src/sample.py" <<'PY'
class Widget:
    def __init__(self, size):
        self.size = size

    def area(self):
        return self.size * self.size


def build(n):
    return [Widget(i) for i in range(n)]
PY
git -C "${CTX_TMP}" init -q
git -C "${CTX_TMP}" add -A
git -C "${CTX_TMP}" -c user.email=t@t -c user.name=t commit -qm init

python3 bench/scripts/bench-context.py --root "${CTX_TMP}" --json 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d["schema"] == "aidd-bench-context/1", d.get("schema")
# Tokens and parity must stay unmeasured — bytes are never laundered into either.
assert d["tokens_input"] is None, "tokens_input must be null"
assert d["tokens_output"] is None, "tokens_output must be null"
assert d["usage_source"] == "not-measured", d["usage_source"]
assert d["defect_detection_parity"] is None, "parity must be null without a graded run"
# The measured half must actually be measured.
assert d["targets"] > 0, "no targets selected"
assert d["baseline_bytes"] > 0, "baseline not measured"
assert d["query_bytes"] > 0, "query arm not measured"
# NOT asserted: that the query arm is cheaper. On a small file with many targets
# it is not — spans are charged per target while the baseline dedupes the file.
# A benchmark that can only report a win is not a benchmark, so the tool must be
# able to return a negative ratio and this suite must tolerate one.
assert isinstance(d["reduction_ratio"], float), d["reduction_ratio"]
assert d["reduction_ratio"] < 1, "ratio of 1 would mean zero-cost reads"
# Run identity is recorded so a dirty-tree result is detectable after the fact.
assert "framework_tree_dirty" in d, "tree-dirty flag missing"
assert "framework_head" in d, "head missing"
'
check "bench-context.py measures bytes and leaves tokens/parity unmeasured" $?

python3 bench/scripts/bench-context.py --root "${CTX_TMP}" --sample 2 --json 2>/dev/null \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d["targets"]==2 else 1)'
check "bench-context.py --sample caps the target set deterministically" $?

# The loss regime, asserted rather than assumed: many targets in one small file
# is the shape where reading the whole file once beats reading spans repeatedly.
# If this ever stops being negative the cost model has changed and the docs lie.
python3 bench/scripts/bench-context.py --root "${CTX_TMP}" --json 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
sys.exit(0 if d["reduction_ratio"] < 0 else 1)'
check "bench-context.py reports a negative ratio when spans lose (small file, many targets)" $?

rm -rf "${CTX_TMP}"

grep -q 'Context-cost arm' bench/harness.md
check "harness.md documents the context-cost arm" $?
grep -q 'No cost constant may move on this arm alone' bench/harness.md
check "harness.md states the no-constant-moves rule for the bytes arm" $?

exit "${fail}"
