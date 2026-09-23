#!/usr/bin/env bash
# Behavior tests for delivery preflight; no model, network, or third-party packages.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tests/readiness_checks.py
