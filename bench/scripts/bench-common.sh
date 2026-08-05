#!/usr/bin/env bash
# Shared helpers for the bench scripts. Sourced, never executed directly.
# Zero hard dependencies: bash + python3 stdlib + git (ADR 002).
# NOTE: a comment must not begin with the word "shellcheck" — it parses as a directive.

BENCH_REPO_ROOT="${BENCH_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export BENCH_REPO_ROOT
BENCH_SCRIPTS="${BENCH_REPO_ROOT}/bench/scripts"
BENCH_TASK_DIR="${BENCH_REPO_ROOT}/bench/tasks"
BENCH_DEFECT_DIR="${BENCH_REPO_ROOT}/bench/defects"

bench_die() { printf 'error: %s\n' "$*" >&2; exit 1; }
bench_warn() { printf 'warning: %s\n' "$*" >&2; }

# ISO-8601 UTC, the only timestamp format the harness records (bench/harness.md).
bench_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
bench_stamp() { date -u +%Y%m%dT%H%M%SZ; }
bench_epoch() { python3 -c 'import time; print(f"{time.time():.3f}")'; }

bench_meta() { # file, field
  python3 "${BENCH_SCRIPTS}/bench_meta.py" --file "$1" --field "$2"
}

bench_task_file() { # task-id
  printf '%s/%s.md' "${BENCH_TASK_DIR}" "$1"
}

bench_defect_file() { # defect-id
  printf '%s/%s.md' "${BENCH_DEFECT_DIR}" "$1"
}

# Evidence block in the mandatory format from core/protocol/evidence.md:
#   $ <command> / <trimmed output> / [exit <code>] <ISO-8601 timestamp>
bench_evidence() { # command-string, exit-code, log-file
  printf '```text\n$ %s\n' "$1"
  if [ -f "$3" ]; then
    head -n 8 "$3"
    if [ "$(wc -l <"$3" | tr -d ' ')" -gt 16 ]; then
      printf '...\n'
      tail -n 8 "$3"
    fi
  else
    printf '(no output captured)\n'
  fi
  printf '[exit %s] %s\n```\n' "$2" "$(bench_now)"
}

# Write a task/defect block to a file and run it as its own bash -euo pipefail script.
# Each block gets its own shell, so a `cd` in one never leaks into the next.
bench_run_block() { # block-text, script-path, work-dir, log-path
  printf '#!/usr/bin/env bash\nset -euo pipefail\n%s\n' "$1" >"$2"
  ( cd "$3" && BENCH_REPO_ROOT="${BENCH_REPO_ROOT}" bash "$2" ) >"$4" 2>&1
}

bench_require_clean_tree() { # dir
  git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    bench_die "$1 is not a git work tree — injection needs git to be reversible"
  [ -z "$(git -C "$1" status --porcelain)" ] ||
    bench_die "$1 has uncommitted changes — refusing to inject into a dirty tree"
}
