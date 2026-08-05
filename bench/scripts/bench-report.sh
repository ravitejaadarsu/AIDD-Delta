#!/usr/bin/env bash
# Aggregate a run directory into bench/results/<run-id>/report.md using the shipped template.
set -uo pipefail
# shellcheck source=bench/scripts/bench-common.sh
. "$(cd "$(dirname "$0")" && pwd)/bench-common.sh"

usage() {
  cat <<'USAGE'
bench-report.sh — aggregate one run's metrics into a report.

Usage:
  bench-report.sh --run-id ID [options]
  bench-report.sh --run-dir DIR [options]

Options:
  --run-id ID            a directory name under the results root
  --run-dir DIR          the run directory directly
  --results DIR          results root (default bench/results)
  --baseline-run-dir DIR a separate run holding the baseline arm, when the arms were run
                         apart. Omitted, the baseline is taken from reps whose driver is
                         `baseline` inside this run.
  --template PATH        report template (default bench/results/TEMPLATE.md)
  --out PATH             output path (default <run-dir>/report.md)
  -h, --help             this text

What it reports: per-task pass/fail with medians and ranges, defects caught versus missed
BY LAYER, token cost, wall-clock, and the derived metrics — defect-detection rate, escape
rate, cost per caught defect, and cost overhead versus the baseline arm.

Every number traces to a recorded measurement in a metrics.json. Any statistic whose inputs
are all null renders `not measured`, and so does every derived metric that depends on it.
Nothing is inferred, estimated, or defaulted to zero (bench/harness.md).

Without baseline reps, the overhead rows read `not measured`: there is no comparative claim
to make without a control arm (ADR 014).

Exit codes: 0 report written, 1 aggregation failed, 2 usage error.
USAGE
}

run_id=""
run_dir=""
results_root=""
baseline_dir=""
template=""
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --run-id) [ $# -ge 2 ] || { usage; exit 2; }; run_id="$2"; shift 2 ;;
    --run-dir) [ $# -ge 2 ] || { usage; exit 2; }; run_dir="$2"; shift 2 ;;
    --results) [ $# -ge 2 ] || { usage; exit 2; }; results_root="$2"; shift 2 ;;
    --baseline-run-dir) [ $# -ge 2 ] || { usage; exit 2; }; baseline_dir="$2"; shift 2 ;;
    --template) [ $# -ge 2 ] || { usage; exit 2; }; template="$2"; shift 2 ;;
    --out) [ $# -ge 2 ] || { usage; exit 2; }; out="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument %s\n\n' "$1" >&2; usage; exit 2 ;;
  esac
done

results_root="${results_root:-${BENCH_REPO_ROOT}/bench/results}"
template="${template:-${BENCH_REPO_ROOT}/bench/results/TEMPLATE.md}"
if [ -z "${run_dir}" ]; then
  [ -n "${run_id}" ] || { usage; exit 2; }
  run_dir="${results_root}/${run_id}"
fi
[ -d "${run_dir}" ] || bench_die "${run_dir} does not exist"
[ -f "${template}" ] || bench_die "template ${template} does not exist"
out="${out:-${run_dir}/report.md}"

args=(aggregate --run-dir "${run_dir}" --template "${template}" --out "${out}")
[ -n "${baseline_dir}" ] && args+=(--baseline-run-dir "${baseline_dir}")
python3 "${BENCH_SCRIPTS}/bench_metrics.py" "${args[@]}" || bench_die "aggregation failed"

if ! grep -q 'not measured' "${out}"; then
  bench_warn "${out} contains no 'not measured' cell — check that unmeasured values were not filled in"
fi
printf 'report: %s\n' "${out}"
