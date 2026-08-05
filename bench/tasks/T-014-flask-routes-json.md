---
id: T-014-flask-routes-json
title: Add a machine-readable JSON output mode to the flask routes command
repo: https://github.com/pallets/flask
commit: 6a2f545bfd8ed31e19066a299296917e034aca58
verified: true
class: feature
expected_rigor: standard
difficulty: 3
token_budget_hint: 70000
setup: |
  git clone --no-checkout --filter=blob:none https://github.com/pallets/flask.git ./repo
  git -C ./repo checkout --detach 6a2f545bfd8ed31e19066a299296917e034aca58
  cd ./repo
  python3 -m venv .venv
  ./.venv/bin/pip install -q -e ".[dev]" || ./.venv/bin/pip install -q -e .
  printf 'from flask import Flask\napp = Flask(__name__)\n\n\n@app.get("/ping")\ndef ping():\n    return "pong"\n' > ./bench_app.py
intent: Add a JSON output mode to the flask routes CLI command that prints one object per route with its rule, endpoint, and methods
pretest: |
  cd ./repo
  test -f ./bench_app.py || exit 3
  test -x ./.venv/bin/flask || exit 3
  ./.venv/bin/flask --app bench_app routes --json > ./routes.json 2>/dev/null || exit 1
  ./.venv/bin/python -c "import json; d=json.load(open('routes.json')); raise SystemExit(0 if isinstance(d, list) and any(r.get('rule')=='/ping' for r in d) else 1)"
acceptance: |
  1. `flask --app bench_app routes --json` exits 0 and writes a JSON array on stdout.
  2. Each element has at least `rule`, `endpoint`, and `methods`.
  3. The array contains the `/ping` route registered by the bench app.
  4. The default (non-JSON) output of `flask routes` is unchanged.
  5. The repository's own test suite is green.
oracle: |
  cd ./repo
  ./.venv/bin/flask --app bench_app routes > ./routes.txt
  grep -q "/ping" ./routes.txt
  ./.venv/bin/flask --app bench_app routes --json > ./routes.json
  ./.venv/bin/python -c "import json; d=json.load(open('routes.json')); r=[x for x in d if x.get('rule')=='/ping']; raise SystemExit(0 if r and {'rule','endpoint','methods'} <= set(r[0]) else 1)"
  ./.venv/bin/python -m pytest -q
notes: |
  `verified: true` means the pinned SHA was confirmed to exist by `git ls-remote` on
  2026-08-06, nothing more. `setup` writes `bench_app.py` so the CLI has something to
  enumerate; that file is part of the task fixture, not of the change under test. The oracle
  checks the plain-text output first, so an arm that replaces the human output with JSON
  fails criterion 4.
---

# T-014 — JSON output for a CLI

## Context

`flask routes` prints a human-readable table. This task adds a machine-readable mode
alongside it.

## Why this task

Adding an output format touches CLI plumbing, formatting, and tests at once, and it has an
obvious regression trap: replacing the existing output instead of adding to it. Both halves
are graded.

## Grading

Plain output still contains the route, JSON output parses and carries the three required
keys, and the repository suite is green.
