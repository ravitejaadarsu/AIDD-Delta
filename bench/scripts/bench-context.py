#!/usr/bin/env python3
"""Measure context cost: read-everything vs query-locally, in bytes.

Why this exists separately from `bench-run.sh`: that harness measures a *run* —
tokens from the runtime's own usage output, defects caught, wall clock. It needs
a funded driver. This measures the one thing that can be established with no
credentials and no model call at all: **how many bytes of context each read
strategy assembles** for the same set of questions.

That is deliberately not a token count, and this script never pretends
otherwise. `harness.md` forbids the harness from tokenizing or estimating, so
`tokens_input` here is `null` and `usage_source` is `not-measured` unless a real
usage source supplies them. Bytes drive tokens, they are exactly reproducible,
and they are honest about being bytes.

The two arms answer the same question — "show me symbol S" — the way each
strategy actually would:

  baseline : read the whole file containing S (deduplicated across targets,
             because a role that already read a file does not re-read it)
  query    : read index.json once, then S's span per target

Both arms are reported with and without the index's fixed cost, since the index
is paid once per rebuild rather than once per read.

Usage:
  bench-context.py                        # measure this repo, print a report
  bench-context.py --json                 # machine-readable
  bench-context.py --out results/x.json   # write the metrics object
  bench-context.py --sample 40            # cap the target set (deterministic)
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

SCHEMA = "aidd-bench-context/1"


def load_indexer(root):
    """Import the framework's own indexer.

    Search order matters: the measured repo may be some *other* project with the
    framework vendored into it, or no framework at all. The last candidate is the
    framework this script itself ships in, so measuring a foreign repo works —
    without it, this only ever ran against AIDD Delta, which is not the point.
    """
    import importlib.util
    here = os.path.dirname(os.path.abspath(__file__))
    for cand in (os.path.join(root, ".aidd", "framework", "scripts", "aidd-index.py"),
                 os.path.join(root, "core", "scripts", "aidd-index.py"),
                 os.path.normpath(os.path.join(here, "..", "..", "core", "scripts", "aidd-index.py"))):
        if os.path.exists(cand):
            spec = importlib.util.spec_from_file_location("aidd_index", cand)
            if spec is None or spec.loader is None:
                continue
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            return mod
    return None


def select_targets(index, sample):
    """Deterministically choose the symbols to ask for.

    Deterministic selection matters more than a large sample: a benchmark whose
    target set moves between runs cannot be compared against itself. Sorting and
    striding gives the same set on every host, and spreads targets across files
    rather than clustering them wherever parsing happened to work best.
    """
    targets = []
    for rel in sorted(index.get("files", {})):
        entry = index["files"][rel]
        for sym in entry.get("symbols", []):
            targets.append((rel, sym["name"], sym["start"], sym["end"]))
    if sample and len(targets) > sample:
        stride = len(targets) / float(sample)
        targets = [targets[int(i * stride)] for i in range(sample)]
    return targets


def measure(root, index_path, targets):
    """Bytes each arm assembles to answer the same set of questions."""
    baseline_files, baseline_bytes = set(), 0
    query_bytes = 0
    missing = 0

    for rel, _name, start, end in targets:
        path = os.path.join(root, rel)
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                lines = fh.read().split("\n")
        except OSError:
            missing += 1
            continue

        # Baseline: the whole file, charged once however many symbols we want
        # from it — a role that already read the file does not re-read it.
        if rel not in baseline_files:
            baseline_files.add(rel)
            baseline_bytes += sum(len(line) + 1 for line in lines)

        # Query: just the span, charged per target, because each is a separate
        # read. This is the query arm's honest worst case.
        span = lines[max(start - 1, 0):end]
        query_bytes += sum(len(line) + 1 for line in span)

    index_bytes = os.path.getsize(index_path) if os.path.exists(index_path) else 0
    return {
        "targets": len(targets),
        "targets_unreadable": missing,
        "baseline_files_read": len(baseline_files),
        "baseline_bytes": baseline_bytes,
        "query_bytes": query_bytes,
        "index_bytes": index_bytes,
        "query_bytes_with_index": query_bytes + index_bytes,
    }


def derive(m):
    """Ratios, guarded so an empty corpus reports null rather than dividing."""
    base = m["baseline_bytes"]
    if not base:
        return {"reduction_ratio": None, "reduction_ratio_with_index": None}
    return {
        "reduction_ratio": round(1 - (m["query_bytes"] / base), 4),
        "reduction_ratio_with_index": round(1 - (m["query_bytes_with_index"] / base), 4),
    }


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Measure read-everything vs query-locally context cost, in bytes.")
    ap.add_argument("--root", default=None)
    ap.add_argument("--sample", type=int, default=0, help="cap targets (deterministic stride)")
    ap.add_argument("--out", default=None, help="write the metrics object here")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    root = args.root or subprocess.run(
        ("git", "rev-parse", "--show-toplevel"), capture_output=True, text=True, check=False
    ).stdout.strip()
    if not root:
        print("bench-context: not a git repository", file=sys.stderr)
        return 1
    root = os.path.abspath(root)

    ix = load_indexer(root)
    if ix is None:
        print("bench-context: indexer not found; cannot measure the query arm", file=sys.stderr)
        return 2

    index_path = os.path.join(root, ".aidd", "context", "index.json")
    index = ix.load_index(index_path)
    if index is None:
        index, _ = ix.build(root, index_path)
        os.makedirs(os.path.dirname(index_path), exist_ok=True)
        tmp = index_path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(index, fh, separators=(",", ":"), sort_keys=True)
        os.replace(tmp, index_path)

    targets = select_targets(index, args.sample)
    m = measure(root, index_path, targets)
    m.update(derive(m))

    head = subprocess.run(("git", "-C", root, "rev-parse", "HEAD"),
                          capture_output=True, text=True, check=False).stdout.strip()
    dirty = bool(subprocess.run(("git", "-C", root, "status", "--porcelain"),
                                capture_output=True, text=True, check=False).stdout.strip())

    metrics = {
        "schema": SCHEMA,
        "measured_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "framework_head": head or None,
        "framework_tree_dirty": dirty,
        "parser": index.get("parser"),
        # Bytes are measured. Tokens are NOT, and are never derived from bytes —
        # harness.md forbids estimating them, and a guess in a measured column is
        # worse than an absent value (cost-governance.md).
        "tokens_input": None,
        "tokens_output": None,
        "usage_source": "not-measured",
        # Parity needs two graded runs with a real driver. Until then this stays
        # null, and no cost constant may be revised on the strength of bytes alone.
        "defect_detection_parity": None,
        "notes": ("bytes measured deterministically; tokens and defect parity require a "
                  "funded driver run via bench-run.sh"),
    }
    metrics.update(m)

    if args.out:
        os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as fh:
            json.dump(metrics, fh, indent=2, sort_keys=True)

    if args.json:
        print(json.dumps(metrics, indent=2, sort_keys=True))
        return 0

    def pct(v):
        return "not measured" if v is None else "%.1f%%" % (v * 100)

    print("# Context cost - read-everything vs query-locally")
    print()
    print("Framework HEAD: %s%s" % ((head or "unknown")[:12], " (DIRTY)" if dirty else ""))
    print("Parser: %s | targets: %d symbols across %d files"
          % (metrics["parser"], m["targets"], m["baseline_files_read"]))
    print()
    print("| Arm | Bytes of context |")
    print("|---|---|")
    print("| baseline - whole file per symbol (deduped) | %s |" % f"{m['baseline_bytes']:,}")
    print("| query - spans only | %s |" % f"{m['query_bytes']:,}")
    print("| query + index (index charged once) | %s |" % f"{m['query_bytes_with_index']:,}")
    print()
    print("Reduction, spans only:      %s" % pct(m["reduction_ratio"]))
    print("Reduction, index amortized: %s" % pct(m["reduction_ratio_with_index"]))
    print()
    print("Tokens: not measured (no usage source). Defect-detection parity: not measured.")
    print("Bytes drive tokens but are not tokens. No cost constant may move on this alone -")
    print("run bench-run.sh with a funded driver for tokens and parity (harness.md).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
