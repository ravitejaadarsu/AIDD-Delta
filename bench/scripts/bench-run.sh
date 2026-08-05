#!/usr/bin/env bash
# Run one or more bench tasks against a driver, or validate the corpus mechanically.
# Never exits on the first failure: a failed rep is recorded and reported, not hidden.
set -uo pipefail
# shellcheck source=bench/scripts/bench-common.sh
. "$(cd "$(dirname "$0")" && pwd)/bench-common.sh"

usage() {
  cat <<'USAGE'
bench-run.sh — run bench tasks against a driver, or validate the corpus with no model.

Usage:
  bench-run.sh [selection] [options]

Selection (default: every task, filtered by --class / --offline):
  --task ID          one task; repeatable
  --all              every task in bench/tasks/
  --class C          bugfix | feature | refactor | security | migration | docs
  --offline          only local: fixture tasks; forbids network and remote repos

Options:
  --driver D         aidd | baseline | external:<cmd>   (default: aidd)
                     `baseline` is the control arm: one agent, no verification layers.
                     `aidd` reads $BENCH_AIDD_CMD; `baseline` reads $BENCH_BASELINE_CMD.
  --defect ID        inject a defect from bench/defects/ after setup
  --reps N           repetitions per task (default 1; >=3 for any published claim)
  --run-id ID        override the generated run id
  --results DIR      results root (default bench/results)
  --dry-run          validate every task, oracle, and setup mechanically; emit a plan.
                     Invokes no model and needs no network or API key. This is what CI runs.
  --preflight        run setup + pretest only, then stop (proves a task is still unsatisfied)
  --grade            run bench-grade.sh after each rep
  -h, --help         this text

The driver receives the task's `intent` verbatim on stdin and in $BENCH_INTENT, runs with
CWD set to the rep's work dir, and reports token usage by writing $BENCH_USAGE_FILE:
  {"tokens_input": 1234, "tokens_output": 567, "cost_usd": null}
Missing usage data is recorded as `not measured` — never estimated (bench/harness.md).

Exit codes: 0 all reps completed, 1 at least one rep failed, 2 usage error,
3 the selected driver is not configured.
USAGE
}

task_ids=()
want_class=""
offline=0
driver="aidd"
defect_id=""
reps=1
run_id=""
results_root=""
dry_run=0
preflight=0
do_grade=0

while [ $# -gt 0 ]; do
  case "$1" in
    --task) [ $# -ge 2 ] || { usage; exit 2; }; task_ids+=("$2"); shift 2 ;;
    --all) shift ;;
    --class) [ $# -ge 2 ] || { usage; exit 2; }; want_class="$2"; shift 2 ;;
    --offline) offline=1; shift ;;
    --driver) [ $# -ge 2 ] || { usage; exit 2; }; driver="$2"; shift 2 ;;
    --defect) [ $# -ge 2 ] || { usage; exit 2; }; defect_id="$2"; shift 2 ;;
    --reps) [ $# -ge 2 ] || { usage; exit 2; }; reps="$2"; shift 2 ;;
    --run-id) [ $# -ge 2 ] || { usage; exit 2; }; run_id="$2"; shift 2 ;;
    --results) [ $# -ge 2 ] || { usage; exit 2; }; results_root="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --preflight) preflight=1; shift ;;
    --grade) do_grade=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown argument %s\n\n' "$1" >&2; usage; exit 2 ;;
  esac
done

results_root="${results_root:-${BENCH_REPO_ROOT}/bench/results}"
case "${reps}" in ''|*[!0-9]*) bench_die "--reps must be a positive integer" ;; esac
[ "${reps}" -ge 1 ] || bench_die "--reps must be at least 1"

# ---- resolve the task list ------------------------------------------------

list_args=(--list tasks)
[ -n "${want_class}" ] && list_args+=(--class "${want_class}")
[ "${offline}" -eq 1 ] && list_args+=(--offline)
listing="$(python3 "${BENCH_SCRIPTS}/bench_meta.py" "${list_args[@]}")" ||
  bench_die "corpus listing failed — a task file has malformed frontmatter"

selected=()
while IFS=$'\t' read -r id _rest; do
  [ -n "${id}" ] || continue
  if [ "${#task_ids[@]}" -gt 0 ]; then
    for want in "${task_ids[@]}"; do
      [ "${want}" = "${id}" ] && selected+=("${id}")
    done
  else
    selected+=("${id}")
  fi
done <<<"${listing}"

if [ "${#task_ids[@]}" -gt 0 ] && [ "${#selected[@]}" -ne "${#task_ids[@]}" ]; then
  bench_die "one or more --task ids matched no task under the current filters"
fi
[ "${#selected[@]}" -gt 0 ] || bench_die "no tasks selected"

# ---- dry run: validate everything, invoke nothing --------------------------

if [ "${dry_run}" -eq 1 ]; then
  fail=0
  offline_count=0
  for id in "${selected[@]}"; do
    file="$(bench_task_file "${id}")"
    if ! python3 "${BENCH_SCRIPTS}/bench_meta.py" --file "${file}" --validate task >/dev/null; then
      printf 'INVALID %s\n' "${id}"
      fail=1
      continue
    fi
    # Every ${BENCH_REPO_ROOT}-relative helper the executable blocks reference must exist,
    # so a task can never point at a grader that is not on disk.
    while read -r helper; do
      [ -n "${helper}" ] || continue
      if [ ! -e "${BENCH_REPO_ROOT}/${helper}" ]; then
        printf 'MISSING-HELPER %s -> %s\n' "${id}" "${helper}"
        fail=1
      fi
    done < <(python3 "${BENCH_SCRIPTS}/bench_meta.py" --file "${file}" --helpers)

    IFS=$'\t' read -r klass rigor difficulty repo budget < <(
      python3 "${BENCH_SCRIPTS}/bench_meta.py" --file "${file}" \
        --fields class,expected_rigor,difficulty,repo,token_budget_hint)
    case "${repo}" in local:*) offline_count=$((offline_count + 1)) ;; esac
    printf 'PLAN %s class=%s rigor=%s difficulty=%s repo=%s reps=%s driver=%s budget=%s\n' \
      "${id}" "${klass}" "${rigor}" "${difficulty}" "${repo}" "${reps}" "${driver}" "${budget}"
  done
  if [ -n "${defect_id}" ]; then
    dfile="$(bench_defect_file "${defect_id}")"
    if python3 "${BENCH_SCRIPTS}/bench_meta.py" --file "${dfile}" --validate defect >/dev/null; then
      printf 'PLAN-DEFECT %s mode=%s visible_to=%s\n' "${defect_id}" \
        "$(bench_meta "${dfile}" injection_mode)" "$(bench_meta "${dfile}" visible_to)"
    else
      printf 'INVALID-DEFECT %s\n' "${defect_id}"
      fail=1
    fi
  fi
  printf 'dry-run %s: %s task(s) validated, %s offline, no driver invoked\n' \
    "$([ "${fail}" -eq 0 ] && echo OK || echo FAILED)" "${#selected[@]}" "${offline_count}"
  exit "${fail}"
fi

# ---- resolve the driver ----------------------------------------------------

driver_cmd=""
case "${driver}" in
  aidd) driver_cmd="${BENCH_AIDD_CMD:-}" ;;
  baseline) driver_cmd="${BENCH_BASELINE_CMD:-}" ;;
  external:*) driver_cmd="${driver#external:}" ;;
  *) bench_die "--driver must be aidd, baseline, or external:<cmd>" ;;
esac
if [ "${preflight}" -eq 0 ] && [ -z "${driver_cmd}" ]; then
  printf 'error: driver %s is not configured.\n' "${driver}" >&2
  printf '  set BENCH_AIDD_CMD / BENCH_BASELINE_CMD, or pass --driver external:<cmd>.\n' >&2
  printf '  the harness ships no model and no API key by design (bench/harness.md).\n' >&2
  exit 3
fi

corpus_tag="all"
[ "${offline}" -eq 1 ] && corpus_tag="offline"
[ -n "${want_class}" ] && corpus_tag="class-${want_class}"
[ "${#task_ids[@]}" -gt 0 ] && corpus_tag="selected"
run_id="${run_id:-$(bench_stamp)-${driver%%:*}-${corpus_tag}}"
run_dir="${results_root}/${run_id}"
mkdir -p "${run_dir}" || bench_die "cannot create ${run_dir}"

{
  printf '# Environment capture\n\n'
  printf '```text\n'
  printf 'captured_at: %s\n' "$(bench_now)"
  printf 'run_id: %s\n' "${run_id}"
  printf 'driver: %s\n' "${driver}"
  printf 'corpus_tag: %s\n' "${corpus_tag}"
  printf 'reps_requested: %s\n' "${reps}"
  printf 'defect: %s\n' "${defect_id:-none}"
  printf 'framework_head: %s\n' "$(git -C "${BENCH_REPO_ROOT}" rev-parse HEAD 2>/dev/null || echo unknown)"
  if [ -n "$(git -C "${BENCH_REPO_ROOT}" status --porcelain 2>/dev/null)" ]; then
    printf 'framework_tree: DIRTY (this run is disqualified from a published claim)\n'
  else
    printf 'framework_tree: clean\n'
  fi
  printf 'uname: %s\n' "$(uname -a)"
  printf 'bash: %s\n' "${BASH_VERSION}"
  printf 'python3: %s\n' "$(python3 --version 2>&1)"
  printf 'git: %s\n' "$(git --version 2>&1)"
  env | grep '^BENCH_' | sed -E 's/^(BENCH_[A-Za-z0-9_]*(KEY|TOKEN|SECRET)[A-Za-z0-9_]*)=.*/\1=<redacted>/'
  printf '```\n'
} >"${run_dir}/env.md"

# ---- execute ---------------------------------------------------------------

exit_code=0
for id in "${selected[@]}"; do
  file="$(bench_task_file "${id}")"
  intent="$(bench_meta "${file}" intent)"
  rep=1
  while [ "${rep}" -le "${reps}" ]; do
    rep_dir="${run_dir}/${id}/rep-${rep}"
    mkdir -p "${rep_dir}/work"
    metrics="${rep_dir}/metrics.json"
    python3 "${BENCH_SCRIPTS}/bench_metrics.py" write --out "${metrics}" \
      "run_id=${run_id}" "task_id=${id}" "rep=${rep}" "driver=${driver}" \
      "defect_id=${defect_id:-null}" "started_at=$(bench_now)"

    if ! bench_run_block "$(bench_meta "${file}" setup)" "${rep_dir}/setup.sh" \
         "${rep_dir}/work" "${rep_dir}/setup.log"; then
      python3 "${BENCH_SCRIPTS}/bench_metrics.py" set --file "${metrics}" \
        setup_status=fail "notes=setup failed; see setup.log"
      printf 'SETUP-FAIL %s rep %s\n' "${id}" "${rep}"
      exit_code=1
      rep=$((rep + 1))
      continue
    fi
    python3 "${BENCH_SCRIPTS}/bench_metrics.py" set --file "${metrics}" setup_status=ok

    bench_run_block "$(bench_meta "${file}" pretest)" "${rep_dir}/pretest.sh" \
      "${rep_dir}/work" "${rep_dir}/pretest.log"
    pre_rc=$?
    case "${pre_rc}" in
      0) status="already-satisfied" ;;
      1) status="unsatisfied-as-required" ;;
      *) status="error" ;;
    esac
    python3 "${BENCH_SCRIPTS}/bench_metrics.py" set --file "${metrics}" "pretest_status=${status}"
    if [ "${status}" != "unsatisfied-as-required" ]; then
      printf 'PRETEST-%s %s rep %s (exit %s)\n' "$(printf '%s' "${status}" | tr 'a-z-' 'A-Z_')" \
        "${id}" "${rep}" "${pre_rc}"
      exit_code=1
      rep=$((rep + 1))
      continue
    fi

    if [ -n "${defect_id}" ]; then
      if ! bash "${BENCH_SCRIPTS}/bench-inject.sh" --defect "${defect_id}" --apply \
           --work-dir "${rep_dir}/work" >"${rep_dir}/inject.log" 2>&1; then
        printf 'INJECT-NOT-APPLIED %s (see %s/inject.log)\n' "${defect_id}" "${rep_dir}"
        python3 "${BENCH_SCRIPTS}/bench_metrics.py" set --file "${metrics}" \
          "notes=defect ${defect_id} was not applied mechanically; see inject.log"
      fi
    fi

    if [ "${preflight}" -eq 1 ]; then
      printf 'PREFLIGHT-OK %s rep %s (setup ok, pretest unsatisfied as required)\n' "${id}" "${rep}"
      rep=$((rep + 1))
      continue
    fi

    printf '%s\n' "${intent}" >"${rep_dir}/intent.txt"
    start="$(bench_epoch)"
    (
      cd "${rep_dir}/work" &&
      BENCH_INTENT="${intent}" BENCH_USAGE_FILE="${rep_dir}/usage.json" \
        bash -c "${driver_cmd}" <"${rep_dir}/intent.txt"
    ) >"${rep_dir}/driver.log" 2>&1
    driver_rc=$?
    end="$(bench_epoch)"
    elapsed="$(python3 -c "print(f'{${end} - ${start}:.3f}')")"

    # Tokens come from the runtime's own usage output, never from an estimate. A missing or
    # unparseable usage file leaves every token field null, which reports as `not measured`.
    usage_args=(usage_source=not-measured tokens_input=null tokens_output=null tokens_total=null)
    parsed="$(python3 "${BENCH_SCRIPTS}/bench_metrics.py" usage "${rep_dir}/usage.json" 2>/dev/null)"
    if [ -n "${parsed}" ]; then
      read -r -a usage_args <<<"${parsed}"
    fi

    python3 "${BENCH_SCRIPTS}/bench_metrics.py" set --file "${metrics}" \
      "finished_at=$(bench_now)" "wall_clock_seconds=${elapsed}" "${usage_args[@]}" \
      "notes=driver exit ${driver_rc}"
    [ "${driver_rc}" -eq 0 ] || exit_code=1
    printf 'RAN %s rep %s driver-exit=%s wall=%ss\n' "${id}" "${rep}" "${driver_rc}" "${elapsed}"

    if [ "${do_grade}" -eq 1 ]; then
      bash "${BENCH_SCRIPTS}/bench-grade.sh" --run-dir "${rep_dir}" || exit_code=1
    fi
    rep=$((rep + 1))
  done
done

printf 'run %s complete: %s\n' "${run_id}" \
  "$([ "${exit_code}" -eq 0 ] && echo "every rep completed" || echo "at least one rep failed — see the logs, and publish it")"
exit "${exit_code}"
