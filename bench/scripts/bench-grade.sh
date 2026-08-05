#!/usr/bin/env bash
# Apply a task's oracle to a completed run dir and emit PASS/FAIL plus an evidence block.
set -uo pipefail
# shellcheck source=bench/scripts/bench-common.sh
. "$(cd "$(dirname "$0")" && pwd)/bench-common.sh"

usage() {
  cat <<'USAGE'
bench-grade.sh — grade one completed rep against its task's committed oracle.

Usage:
  bench-grade.sh --run-dir <bench/results/RUN/TASK/rep-N> [options]

Options:
  --run-dir DIR      the rep directory; must contain metrics.json and work/
  --task ID          override the task id (default: read from metrics.json)
  --defect ID        also run that defect's grader and record which layer caught it
  --quiet            write grade.md but print nothing but the verdict
  -h, --help         this text

The oracle is the committed command in the task's frontmatter. It runs with CWD set to the
rep's work/ dir and decides the grade by its exit code: 0 is PASS, anything else is FAIL.
The verdict is written to grade.md with an evidence block in the mandatory format from
core/protocol/evidence.md — command, trimmed output, exit code, ISO-8601 UTC timestamp —
and mirrored into metrics.json. A grade with no evidence block is not a grade.

A defect grader exits 0 for caught, 1 for escaped, and 2 or more for a grader error, which
is recorded as an error rather than silently counted as a catch.

Exit codes: 0 PASS, 1 FAIL, 2 usage error.
USAGE
}

run_dir=""
task_id=""
defect_id=""
quiet=0
while [ $# -gt 0 ]; do
  case "$1" in
    --run-dir) [ $# -ge 2 ] || { usage; exit 2; }; run_dir="$2"; shift 2 ;;
    --task) [ $# -ge 2 ] || { usage; exit 2; }; task_id="$2"; shift 2 ;;
    --defect) [ $# -ge 2 ] || { usage; exit 2; }; defect_id="$2"; shift 2 ;;
    --quiet) quiet=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument %s\n\n' "$1" >&2; usage; exit 2 ;;
  esac
done

[ -n "${run_dir}" ] || { usage; exit 2; }
[ -d "${run_dir}" ] || bench_die "${run_dir} is not a directory"
[ -d "${run_dir}/work" ] || bench_die "${run_dir}/work is missing — this is not a rep dir"
metrics="${run_dir}/metrics.json"

if [ -z "${task_id}" ]; then
  [ -f "${metrics}" ] || bench_die "no --task given and ${metrics} does not exist"
  task_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["task_id"])' "${metrics}")"
fi
task_file="$(bench_task_file "${task_id}")"
[ -f "${task_file}" ] || bench_die "no task file for ${task_id}"

bench_run_block "$(bench_meta "${task_file}" oracle)" "${run_dir}/oracle.sh" \
  "${run_dir}/work" "${run_dir}/oracle.log"
oracle_rc=$?
grade="FAIL"
[ "${oracle_rc}" -eq 0 ] && grade="PASS"

caught_by="null"
defect_line=""
if [ -n "${defect_id}" ]; then
  defect_file="$(bench_defect_file "${defect_id}")"
  [ -f "${defect_file}" ] || bench_die "no defect file for ${defect_id}"
  bench_run_block "$(bench_meta "${defect_file}" grader)" "${run_dir}/defect-grader.sh" \
    "${run_dir}" "${run_dir}/defect-grader.log"
  defect_rc=$?
  case "${defect_rc}" in
    0)
      caught_by="$(grep -oE 'CAUGHT-BY: [A-Za-z0-9-]+' "${run_dir}/defect-grader.log" |
                   tail -1 | sed 's/CAUGHT-BY: //')"
      caught_by="${caught_by:-unknown}"
      defect_line="defect ${defect_id}: CAUGHT by ${caught_by}"
      ;;
    1) defect_line="defect ${defect_id}: ESCAPED" ;;
    *) defect_line="defect ${defect_id}: GRADER-ERROR (exit ${defect_rc}) — not counted as a catch" ;;
  esac
fi

{
  printf '# Grade — %s\n\n' "${task_id}"
  printf -- '- verdict: **%s**\n' "${grade}"
  printf -- '- graded at: %s\n' "$(bench_now)"
  printf -- '- oracle exit: %s\n' "${oracle_rc}"
  [ -n "${defect_line}" ] && printf -- '- %s\n' "${defect_line}"
  printf '\n## Evidence\n\n'
  bench_evidence "bench-grade.sh --run-dir ${run_dir}  # task oracle" "${oracle_rc}" "${run_dir}/oracle.log"
  if [ -n "${defect_id}" ]; then
    printf '\n'
    bench_evidence "bench-grade.sh --defect ${defect_id}  # defect grader" \
      "${defect_rc:-2}" "${run_dir}/defect-grader.log"
  fi
} >"${run_dir}/grade.md"

if [ -f "${metrics}" ]; then
  python3 "${BENCH_SCRIPTS}/bench_metrics.py" set --file "${metrics}" \
    "grade=${grade}" "defect_caught_by=${caught_by}"
fi

if [ "${quiet}" -eq 0 ]; then
  cat "${run_dir}/grade.md"
else
  printf '%s %s\n' "${grade}" "${task_id}"
fi
[ "${grade}" = "PASS" ]
