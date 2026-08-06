#!/usr/bin/env python3
"""Defect-detection parity: does reading spans instead of whole files lose bugs?

The context pivot claims a role can read one symbol instead of the file holding
it. `bench-context.py` shows that costs fewer tokens. This asks the question that
actually decides whether the pivot is a win: **does the reviewer still find the
bug?** A cheaper run that catches fewer real defects is a regression
(cost-governance.md), so the token saving means nothing on its own.

Method — one injected defect, two arms, N reps:

  baseline : the whole file containing the injected symbol
  query    : the structural index plus that symbol's span, which is what a
             diff-driven review would pull for a changed symbol

Both arms get the identical instruction and must answer as JSON findings with a
`line`. Grading is **mechanical**: caught iff some reported line falls inside the
injected symbol's span. No keyword matching, so the grader cannot be talked into
a catch by a model that merely sounds concerned.

Two defect shapes, because they probe different things:

  local     the fault is inside the span — the query arm should do fine, and if
            it does not, spans are broken outright
  non-local the fault is in a small shared helper whose wrongness is only visible
            at its call sites. The baseline sees the callers; the query arm does
            not. This is the pivot's actual risk, and the reason the experiment
            is worth running rather than assuming.

Costs money: 2 arms x reps x defects calls to the agent CLI. Nothing is written
to bench/results/ — this repository publishes no measured results.

Usage:
  bench-parity.py --reps 3
  bench-parity.py --reps 1 --defect local     # cheaper smoke run
"""

import argparse
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys

SUBJECT = "bench/fixtures/oracles/todo_api.py"

# Each injection names the symbol it lands in, so the grader knows which span
# counts as a catch. `expect` must match exactly once — an ambiguous anchor would
# silently patch the wrong line and invalidate the whole run.
DEFECTS = {
    "local": {
        "symbol": "check_save_traversal",
        "what": "escape assertion inverted inside the span; self-contained",
    },
    "non-local": {
        "symbol": "need",
        "what": "shared assertion helper inverted; wrongness only visible at call sites",
    },
    # The two above are blatant inversions and both arms catch them every time,
    # which means they do not discriminate. This one is the discriminating case:
    # in isolation the helper reads as a plausible early return, and the damage —
    # every assertion in the file silently becoming a no-op — exists only at the
    # call sites the query arm never sees.
    "subtle-non-local": {
        "symbol": "need",
        "what": "assertion helper silently no-ops; plausible in isolation, fatal at call sites",
    },
}

PROMPT = """You are reviewing Python code for defects.

Report ONLY as a JSON array, with no prose before or after:
[{"line": <int>, "problem": "<short description>"}]

`line` is the line number shown in the left-hand gutter of the code below.
If you find no defects, output [].

Code under review:
----
%s
"""


def load_indexer(root):
    path = os.path.join(root, "core", "scripts", "aidd-index.py")
    spec = importlib.util.spec_from_file_location("aidd_index", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def find_symbol(index, rel, name):
    for sym in index["files"][rel]["symbols"]:
        if sym["name"] == name:
            return sym
    raise SystemExit("bench-parity: symbol %s not found in %s" % (name, rel))


def inject(text, sym, replacements):
    """Apply the first replacement whose anchor appears exactly once in the span.

    Anchors are resolved against the symbol's own lines rather than the file, so
    a common expression elsewhere cannot be patched by accident.
    """
    lines = text.split("\n")
    lo, hi = sym["start"] - 1, sym["end"]
    body = "\n".join(lines[lo:hi])
    for expect, replace in replacements:
        if body.count(expect) == 1:
            lines[lo:hi] = body.replace(expect, replace).split("\n")
            return "\n".join(lines), (expect, replace)
    raise SystemExit("bench-parity: no unambiguous anchor in %s" % sym["name"])


def build_payloads(text, rel, sym, symbols):
    """Whole file vs structural index + the changed symbol's span.

    Both carry gutter line numbers so a reported `line` means the same thing in
    each arm — without that, the two arms would not be gradeable on one scale.
    """
    lines = text.split("\n")
    numbered = "\n".join("%4d| %s" % (i + 1, ln) for i, ln in enumerate(lines))
    baseline = "# %s (whole file)\n%s" % (rel, numbered)

    span = lines[sym["start"] - 1:sym["end"]]
    span_numbered = "\n".join("%4d| %s" % (sym["start"] + i, ln)
                              for i, ln in enumerate(span))
    outline = "\n".join("#   %s %s %d-%d" % (s["kind"], s["name"], s["start"], s["end"])
                        for s in symbols)
    query = ("# %s - structural index (symbol map only, bodies not shown)\n%s\n\n"
             "# %s:%d-%d %s (span)\n%s"
             % (rel, outline, rel, sym["start"], sym["end"], sym["name"], span_numbered))
    return baseline, query


def ask(cli, payload):
    """One review call. Returns (findings, cost); findings None on failure."""
    try:
        out = subprocess.run((cli, "-p", "--output-format", "json"),
                             input=PROMPT % payload, capture_output=True,
                             text=True, check=False)
    except OSError:
        return None, None
    if out.returncode != 0:
        return None, None
    try:
        data = json.loads(out.stdout)
    except ValueError:
        return None, None
    text = data.get("result") or ""
    cost = data.get("total_cost_usd")
    match = re.search(r"\[.*\]", text, re.S)
    if not match:
        return [], cost
    try:
        findings = json.loads(match.group(0))
    except ValueError:
        return [], cost
    return [f for f in findings if isinstance(f, dict)], cost


def caught(findings, sym):
    """Mechanical: a catch is a reported line inside the injected symbol's span."""
    for f in findings or []:
        line = f.get("line")
        if isinstance(line, int) and sym["start"] <= line <= sym["end"]:
            return True
    return False


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Measure defect-detection parity across context strategies.")
    ap.add_argument("--reps", type=int, default=3,
                    help="reps per arm per defect (harness wants at least 3)")
    ap.add_argument("--defect", choices=sorted(DEFECTS) + ["all"], default="all")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    cli = shutil.which("claude")
    if cli is None:
        print("bench-parity: no agent CLI on PATH; cannot measure", file=sys.stderr)
        return 2

    root = subprocess.run(("git", "rev-parse", "--show-toplevel"),
                          capture_output=True, text=True, check=False).stdout.strip()
    ix = load_indexer(root)
    index_path = os.path.join(root, ".aidd", "context", "index.json")
    index = ix.load_index(index_path)
    if index is None:
        index, _ = ix.build(root, index_path)

    symbols = sorted(index["files"][SUBJECT]["symbols"], key=lambda s: s["start"])
    original = open(os.path.join(root, SUBJECT), encoding="utf-8").read()
    names = sorted(DEFECTS) if args.defect == "all" else [args.defect]

    # Candidate anchors per defect; the first unambiguous one inside the symbol wins.
    anchors = {
        # An assertion inside the span, inverted: the escape check now passes only
        # when the file DID escape its base directory. Self-contained, so the span
        # alone is enough to see it.
        "local": [('need(not os.path.exists(os.path.join(outside, "escape")), '
                   '"save() wrote outside base")',
                   'need(os.path.exists(os.path.join(outside, "escape")), '
                   '"save() wrote outside base")')],
        "non-local": [("if not cond:", "if cond:"), ("not cond", "cond")],
        # No inversion to spot: the guard still reads correctly, it just stops
        # doing anything. Only the callers reveal that every check is now dead.
        "subtle-non-local": [("        fail(msg)", "        return")],
    }

    results, total_cost = [], 0.0
    for dname in names:
        spec = DEFECTS[dname]
        sym = find_symbol(index, SUBJECT, spec["symbol"])
        injected, used = inject(original, sym, anchors[dname])
        baseline_payload, query_payload = build_payloads(injected, SUBJECT, sym, symbols)

        for arm, payload in (("baseline", baseline_payload), ("query", query_payload)):
            hits = 0
            for _ in range(args.reps):
                findings, cost = ask(cli, payload)
                if isinstance(cost, (int, float)):
                    total_cost += cost
                if caught(findings, sym):
                    hits += 1
            results.append({
                "defect": dname, "shape": spec["what"], "arm": arm,
                "symbol": spec["symbol"], "span": [sym["start"], sym["end"]],
                "anchor": used[0], "reps": args.reps, "caught": hits,
                "catch_rate": round(hits / args.reps, 4) if args.reps else None,
            })

    payload = {
        "schema": "aidd-bench-parity/1",
        "subject": SUBJECT,
        "usage_source": "runtime-usage",
        "measurement_cost_usd": round(total_cost, 6),
        "results": results,
    }
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 0

    print("# Defect-detection parity - whole file vs span")
    print()
    print("Subject: %s | reps per arm: %d | measurement cost: $%.2f"
          % (SUBJECT, args.reps, total_cost))
    print()
    print("| Defect | Arm | Caught / reps | Rate |")
    print("|---|---|---|---|")
    for r in results:
        print("| %s | %s | %d/%d | %.0f%% |"
              % (r["defect"], r["arm"], r["caught"], r["reps"],
                 (r["catch_rate"] or 0) * 100))
    print()
    for dname in names:
        b = next(r for r in results if r["defect"] == dname and r["arm"] == "baseline")
        q = next(r for r in results if r["defect"] == dname and r["arm"] == "query")
        verdict = ("PARITY" if q["caught"] >= b["caught"]
                   else "REGRESSION - the query arm lost defects the baseline caught")
        print("%-10s %s" % (dname, verdict))
        print("           %s" % DEFECTS[dname]["what"])
    print()
    print("A catch is a reported line inside the injected symbol's span - mechanical,")
    print("not keyword matching. Reps are small; treat a single run as directional.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
