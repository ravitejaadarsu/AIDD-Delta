#!/usr/bin/env python3
"""Write and aggregate `metrics.json` records for the bench harness.

Usage:
  bench_metrics.py write --out <path> [key=value ...]
  bench_metrics.py set   --file <path> [key=value ...]
  bench_metrics.py usage <usage.json>
  bench_metrics.py aggregate --run-dir <dir> --template <path> --out <path>
                             [--baseline-run-dir <dir>]

Value syntax: `null` becomes JSON null, a bare integer becomes an int, a bare decimal
becomes a float, anything else stays a string. `null` is the ONLY way a numeric field is
recorded when it was not measured — never 0, never an estimate (bench/harness.md).

Aggregation reads every `<task>/rep-*/metrics.json` under the run dir and substitutes the
`<!-- BENCH:* -->` markers in the template. Any statistic with no non-null input renders as
`not measured`. Stdlib only (ADR 002).
"""

import glob
import json
import os
import sys

NM = "not measured"
SCHEMA = "aidd-bench-metrics/1"

FIELDS = [
    "schema", "run_id", "task_id", "rep", "driver", "defect_id", "started_at", "finished_at",
    "wall_clock_seconds", "tokens_input", "tokens_output", "tokens_total", "usage_source",
    "cost_usd", "setup_status", "pretest_status", "grade", "defect_caught_by", "notes",
]
DEFAULTS = {
    "schema": SCHEMA, "run_id": None, "task_id": None, "rep": 1, "driver": None,
    "defect_id": None, "started_at": None, "finished_at": None, "wall_clock_seconds": None,
    "tokens_input": None, "tokens_output": None, "tokens_total": None,
    "usage_source": "not-measured", "cost_usd": None, "setup_status": "not-run",
    "pretest_status": "not-run", "grade": NM, "defect_caught_by": None, "notes": "",
}


def coerce(raw):
    if raw == "null":
        return None
    try:
        return int(raw)
    except ValueError:
        pass
    try:
        return float(raw)
    except ValueError:
        return raw


def kv(pairs):
    out = {}
    for pair in pairs:
        if "=" not in pair:
            print(f"expected key=value, got {pair!r}", file=sys.stderr)
            raise SystemExit(2)
        key, raw = pair.split("=", 1)
        if key not in FIELDS:
            print(f"unknown metrics field {key!r}; known: {', '.join(FIELDS)}", file=sys.stderr)
            raise SystemExit(2)
        out[key] = coerce(raw)
    return out


def load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def save(path, data):
    ordered = {k: data.get(k, DEFAULTS.get(k)) for k in FIELDS}
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(ordered, fh, indent=2)
        fh.write("\n")


def median(values):
    if not values:
        return None
    ordered = sorted(values)
    mid = len(ordered) // 2
    if len(ordered) % 2:
        return ordered[mid]
    return (ordered[mid - 1] + ordered[mid]) / 2


def fmt(value, unit=""):
    if value is None:
        return NM
    if isinstance(value, float):
        if value == int(value):
            return f"{int(value)}{unit}"
        return f"{value:.2f}{unit}"
    return f"{value}{unit}"


def span(values, unit=""):
    """median (min-max) for a list that may be empty or full of nulls."""
    clean = [v for v in values if isinstance(v, (int, float))]
    if not clean:
        return NM
    if len(clean) == 1:
        return fmt(clean[0], unit)
    return f"{fmt(median(clean), unit)} ({fmt(min(clean), unit)}–{fmt(max(clean), unit)})"


def collect(run_dir):
    reps = []
    for path in sorted(glob.glob(os.path.join(run_dir, "*", "rep-*", "metrics.json"))):
        try:
            data = load(path)
        except (OSError, ValueError) as exc:
            print(f"warning: skipping unreadable {path} ({exc})", file=sys.stderr)
            continue
        data["_path"] = os.path.relpath(path, run_dir)
        reps.append(data)
    return reps


def group(reps):
    buckets = {}
    for rep in reps:
        buckets.setdefault((rep.get("task_id"), rep.get("driver")), []).append(rep)
    return buckets


def per_task_table(reps):
    lines = [
        "| Task | Arm | Reps | Passed | Wall-clock s (median, range) | Tokens (median, range) | Flags |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    if not reps:
        lines.append(f"| {NM} | {NM} | 0 | {NM} | {NM} | {NM} | no metrics files under this run |")
        return "\n".join(lines)
    for (task, driver), rows in sorted(group(reps).items(), key=lambda kv_: (str(kv_[0][0]), str(kv_[0][1]))):
        passed = sum(1 for r in rows if r.get("grade") == "PASS")
        flags = []
        if len(rows) < 3:
            flags.append("UNDER-REPPED")
        for row in rows:
            if row.get("setup_status") == "fail":
                flags.append("SETUP-FAIL")
            if row.get("pretest_status") == "already-satisfied":
                flags.append("PRETEST-ALREADY-SATISFIED")
            if row.get("pretest_status") == "error":
                flags.append("PRETEST-ERROR")
            if row.get("usage_source") == "not-measured":
                flags.append("NO-USAGE-DATA")
        lines.append("| {} | {} | {} | {}/{} | {} | {} | {} |".format(
            task or NM, driver or NM, len(rows), passed, len(rows),
            span([r.get("wall_clock_seconds") for r in rows]),
            span([r.get("tokens_total") for r in rows]),
            ", ".join(sorted(set(flags))) or "-",
        ))
    return "\n".join(lines)


def defect_table(reps):
    defect_reps = [r for r in reps if r.get("defect_id")]
    lines = [
        "| Arm | Layer credited | Defects injected | Caught | Escaped | Detection rate | Escape rate |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    if not defect_reps:
        lines.append(f"| {NM} | {NM} | 0 | {NM} | {NM} | {NM} | {NM} |")
        return "\n".join(lines)
    by_arm = {}
    for rep in defect_reps:
        by_arm.setdefault(rep.get("driver"), []).append(rep)
    for driver, rows in sorted(by_arm.items(), key=lambda kv_: str(kv_[0])):
        layers = {}
        for row in rows:
            layers.setdefault(row.get("defect_caught_by") or "escaped", []).append(row)
        caught_total = sum(len(v) for k, v in layers.items() if k != "escaped")
        for layer, layer_rows in sorted(layers.items()):
            if layer == "escaped":
                continue
            lines.append("| {} | {} | {} | {} | {} | {} | {} |".format(
                driver or NM, layer, len(rows), len(layer_rows), "-",
                f"{len(layer_rows)}/{len(rows)}", "-",
            ))
        escaped = len(layers.get("escaped", []))
        lines.append("| {} | (all layers) | {} | {} | {} | {} | {} |".format(
            driver or NM, len(rows), caught_total, escaped,
            f"{caught_total}/{len(rows)}", f"{escaped}/{len(rows)}",
        ))
    return "\n".join(lines)


def derived_table(reps, baseline_reps):
    tokens = [r.get("tokens_total") for r in reps]
    clocks = [r.get("wall_clock_seconds") for r in reps]
    base_tokens = [r.get("tokens_total") for r in baseline_reps]
    base_clocks = [r.get("wall_clock_seconds") for r in baseline_reps]
    defect_reps = [r for r in reps if r.get("defect_id")]
    caught = [r for r in defect_reps if r.get("defect_caught_by")]
    caught_tokens = [r.get("tokens_total") for r in defect_reps if isinstance(r.get("tokens_total"), (int, float))]

    def ratio(arm, base):
        arm_med = median([v for v in arm if isinstance(v, (int, float))])
        base_med = median([v for v in base if isinstance(v, (int, float))])
        if arm_med is None or base_med in (None, 0):
            return NM
        return f"{arm_med / base_med:.2f}x"

    cost_per_caught = NM
    if caught and caught_tokens and len(caught_tokens) == len(defect_reps):
        cost_per_caught = f"{sum(caught_tokens) / len(caught):.0f} tokens"

    rows = [
        ("pass rate", f"{sum(1 for r in reps if r.get('grade') == 'PASS')}/{len(reps)} reps" if reps else NM),
        ("defect-detection rate", f"{len(caught)}/{len(defect_reps)}" if defect_reps else NM),
        ("escape rate", f"{len(defect_reps) - len(caught)}/{len(defect_reps)}" if defect_reps else NM),
        ("cost per caught defect", cost_per_caught),
        ("cost overhead vs baseline", ratio(tokens, base_tokens)),
        ("wall-clock overhead vs baseline", ratio(clocks, base_clocks)),
        ("median tokens", span(tokens)),
        ("median wall-clock", span(clocks, "s")),
    ]
    lines = ["| Metric | Value |", "| --- | --- |"]
    lines += [f"| {name} | {value} |" for name, value in rows]
    return "\n".join(lines)


def meta_table(run_dir, reps, baseline_reps):
    drivers = sorted({str(r.get("driver")) for r in reps}) or [NM]
    tasks = sorted({str(r.get("task_id")) for r in reps}) or [NM]
    shown = os.path.relpath(run_dir)
    if shown.startswith(".."):
        shown = os.path.abspath(run_dir)
    rows = [
        ("run dir", shown),
        ("arms present", ", ".join(drivers)),
        ("tasks attempted", str(len(tasks))),
        ("reps recorded", str(len(reps)) if reps else "0"),
        ("baseline reps recorded", str(len(baseline_reps)) if baseline_reps else "0 (no comparative claim possible)"),
        ("metrics schema", SCHEMA),
    ]
    lines = ["| Field | Value |", "| --- | --- |"]
    lines += [f"| {name} | {value} |" for name, value in rows]
    return "\n".join(lines)


def evidence_section(run_dir, reps):
    blocks = []
    for rep in reps:
        grade_path = os.path.join(run_dir, os.path.dirname(rep["_path"]), "grade.md")
        if os.path.isfile(grade_path):
            with open(grade_path, encoding="utf-8") as fh:
                blocks.append(f"### {rep.get('task_id')} / {rep.get('driver')} / rep {rep.get('rep')}\n\n"
                              + fh.read().strip() + "\n")
    if not blocks:
        return f"No grade evidence recorded for this run — {NM}."
    return "\n".join(blocks)


def aggregate(run_dir, template, out, baseline_run_dir=None):
    reps = collect(run_dir)
    baseline_reps = collect(baseline_run_dir) if baseline_run_dir else [
        r for r in reps if r.get("driver") == "baseline"
    ]
    with open(template, encoding="utf-8") as fh:
        text = fh.read()
    substitutions = {
        "<!-- BENCH:RUN-META -->": meta_table(run_dir, reps, baseline_reps),
        "<!-- BENCH:PER-TASK -->": per_task_table(reps),
        "<!-- BENCH:DEFECTS-BY-LAYER -->": defect_table(reps),
        "<!-- BENCH:DERIVED -->": derived_table(reps, baseline_reps),
        "<!-- BENCH:EVIDENCE -->": evidence_section(run_dir, reps),
    }
    missing = [marker for marker in substitutions if marker not in text]
    if missing:
        print(f"template {template} is missing markers: {missing}", file=sys.stderr)
        return 1
    for marker, block in substitutions.items():
        text = text.replace(marker, block)
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(text)
    print(f"wrote {out} from {len(reps)} rep record(s)")
    return 0


def main(argv):
    args = argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if args else 2
    mode, rest = args[0], args[1:]

    if mode in ("write", "set"):
        flag = "--out" if mode == "write" else "--file"
        if not rest or rest[0] != flag:
            print(f"usage: bench_metrics.py {mode} {flag} <path> [key=value ...]", file=sys.stderr)
            return 2
        path, pairs = rest[1], rest[2:]
        data = dict(DEFAULTS)
        if mode == "set":
            if not os.path.isfile(path):
                print(f"{path}: no such metrics file", file=sys.stderr)
                return 2
            data.update(load(path))
        data.update(kv(pairs))
        data["schema"] = SCHEMA
        save(path, data)
        return 0

    if mode == "usage":
        # Translate a driver's usage file into metrics key=value pairs. Silent failure is
        # correct here: the caller keeps its `not-measured` defaults when nothing parses.
        if len(rest) != 1:
            print("usage: bench_metrics.py usage <usage.json>", file=sys.stderr)
            return 2
        try:
            data = load(rest[0])
        except (OSError, ValueError):
            return 1
        tin, tout = data.get("tokens_input"), data.get("tokens_output")
        if tin is None and tout is None:
            return 1
        cost = data.get("cost_usd")
        print(
            f"tokens_input={tin if tin is not None else 'null'} "
            f"tokens_output={tout if tout is not None else 'null'} "
            f"tokens_total={(tin or 0) + (tout or 0)} "
            f"cost_usd={cost if cost is not None else 'null'} "
            f"usage_source=runtime-usage"
        )
        return 0

    if mode == "aggregate":
        opts = {}
        i = 0
        while i < len(rest):
            if rest[i] in ("--run-dir", "--template", "--out", "--baseline-run-dir"):
                if i + 1 >= len(rest):
                    print(f"{rest[i]} needs a value", file=sys.stderr)
                    return 2
                opts[rest[i].lstrip("-")] = rest[i + 1]
                i += 2
            else:
                print(f"unknown argument {rest[i]!r}", file=sys.stderr)
                return 2
        for need in ("run-dir", "template", "out"):
            if need not in opts:
                print(f"--{need} is required", file=sys.stderr)
                return 2
        return aggregate(opts["run-dir"], opts["template"], opts["out"], opts.get("baseline-run-dir"))

    print(f"unknown mode {mode!r}; use write, set, usage, or aggregate", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
