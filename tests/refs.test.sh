#!/usr/bin/env bash
# Every path referenced in any markdown file must exist in the repo.
set -uo pipefail
cd "$(dirname "$0")/.."
bash scripts/check-refs.sh
