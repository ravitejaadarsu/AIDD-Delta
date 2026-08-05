#!/usr/bin/env bash
# Apply or revert a catalogued defect in a working copy. Git-based, reversible, and it
# refuses to run on a dirty tree so that --revert can always restore the baseline.
set -uo pipefail
# shellcheck source=bench/scripts/bench-common.sh
. "$(cd "$(dirname "$0")" && pwd)/bench-common.sh"

usage() {
  cat <<'USAGE'
bench-inject.sh — apply or revert an injected defect from bench/defects/.

Usage:
  bench-inject.sh --list
  bench-inject.sh --defect ID --show
  bench-inject.sh --defect ID --apply  --work-dir DIR
  bench-inject.sh --defect ID --revert --work-dir DIR

Options:
  --list             every defect with its class, mode, and hypothesised layer
  --defect ID        the defect to act on
  --show             print the defect's injection and detection signal, change nothing
  --apply            apply it to --work-dir
  --revert           restore --work-dir to its last commit and drop untracked files
  --work-dir DIR     the task's working copy (a git repo created by the task's setup)
  -h, --help         this text

Safety:
  * --apply refuses to run unless the work dir is a git work tree with NO uncommitted
    changes, because --revert restores via `git checkout` and `git clean`.
  * `injection_mode: instruction` defects cannot be applied by a script — they describe a
    behaviour the arm must be asked to produce. Those are printed verbatim and the script
    exits 2 rather than pretending to have applied anything.

Exit codes: 0 applied or reverted, 1 injection failed, 2 instruction-mode or usage error.
USAGE
}

defect_id=""
work_dir=""
action=""
while [ $# -gt 0 ]; do
  case "$1" in
    --list) action="list"; shift ;;
    --show) action="show"; shift ;;
    --apply) action="apply"; shift ;;
    --revert) action="revert"; shift ;;
    --defect) [ $# -ge 2 ] || { usage; exit 2; }; defect_id="$2"; shift 2 ;;
    --work-dir) [ $# -ge 2 ] || { usage; exit 2; }; work_dir="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument %s\n\n' "$1" >&2; usage; exit 2 ;;
  esac
done

if [ "${action}" = "list" ] || { [ -z "${action}" ] && [ -z "${defect_id}" ]; }; then
  printf '%-46s %-22s %-12s %s\n' "DEFECT" "CLASS" "MODE" "HYPOTHESISED LAYER"
  while IFS=$'\t' read -r id _path class mode layers _target; do
    [ -n "${id}" ] || continue
    printf '%-46s %-22s %-12s %s\n' "${id}" "${class}" "${mode}" "${layers}"
  done < <(python3 "${BENCH_SCRIPTS}/bench_meta.py" --list defects)
  exit 0
fi

[ -n "${defect_id}" ] || { usage; exit 2; }
defect_file="$(bench_defect_file "${defect_id}")"
[ -f "${defect_file}" ] || bench_die "no defect file for ${defect_id}"
python3 "${BENCH_SCRIPTS}/bench_meta.py" --file "${defect_file}" --validate defect >/dev/null ||
  bench_die "${defect_id} does not validate against the defect schema"

mode="$(bench_meta "${defect_file}" injection_mode)"
injection="$(bench_meta "${defect_file}" injection)"

if [ "${action}" = "show" ]; then
  printf 'defect: %s\nclass: %s\nmode: %s\nvisible_to: %s\ntarget: %s\n\n' \
    "${defect_id}" "$(bench_meta "${defect_file}" defect_class)" "${mode}" \
    "$(bench_meta "${defect_file}" visible_to)" "$(bench_meta "${defect_file}" target)"
  printf '%s\n%s\n\n%s\n%s\n' \
    "=== injection ===" "${injection}" \
    "=== detection signal ===" "$(bench_meta "${defect_file}" detection_signal)"
  exit 0
fi

[ -n "${work_dir}" ] || bench_die "--work-dir is required for --apply and --revert"
[ -d "${work_dir}" ] || bench_die "${work_dir} is not a directory"

if [ "${action}" = "revert" ]; then
  git -C "${work_dir}" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    bench_die "${work_dir} is not a git work tree — nothing to revert to"
  git -C "${work_dir}" reset -q
  git -C "${work_dir}" checkout -- . || bench_die "git checkout failed in ${work_dir}"
  git -C "${work_dir}" clean -fdq || bench_die "git clean failed in ${work_dir}"
  printf 'reverted %s in %s\n' "${defect_id}" "${work_dir}"
  exit 0
fi

[ "${action}" = "apply" ] || { usage; exit 2; }

if [ "${mode}" = "instruction" ]; then
  printf 'defect %s is instruction-mode and CANNOT be applied mechanically.\n' "${defect_id}" >&2
  printf 'The faulty code does not exist until the arm writes it. Hand the arm this\n' >&2
  printf 'instruction alongside the task intent, and record that you did so:\n\n' >&2
  printf '%s\n\n' "${injection}" >&2
  printf 'Nothing was changed in %s.\n' "${work_dir}" >&2
  exit 2
fi

bench_require_clean_tree "${work_dir}"

script="${work_dir}/.bench-injection.sh"
bench_run_block "${injection}" "${script}" "${work_dir}" "${work_dir}/.bench-injection.log"
rc=$?
rm -f "${script}"
if [ "${rc}" -ne 0 ]; then
  printf 'INJECT-FAIL %s (exit %s)\n' "${defect_id}" "${rc}" >&2
  cat "${work_dir}/.bench-injection.log" >&2
  rm -f "${work_dir}/.bench-injection.log"
  exit 1
fi
rm -f "${work_dir}/.bench-injection.log"
printf 'applied %s to %s\n' "${defect_id}" "${work_dir}"
printf 'revert with: bench-inject.sh --defect %s --revert --work-dir %s\n' "${defect_id}" "${work_dir}"
