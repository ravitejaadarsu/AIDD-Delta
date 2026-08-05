---
id: T-022-fastapi-bearer-401-no-echo
title: A rejected bearer credential must not be echoed in the 401
repo: https://github.com/tiangolo/fastapi
commit: 0622a151c17180fa82ad58b2438c5c3d9574ad6d
verified: true
class: security
expected_rigor: critical
difficulty: 4
token_budget_hint: 80000
setup: |
  git clone --no-checkout --filter=blob:none https://github.com/tiangolo/fastapi.git ./repo
  git -C ./repo checkout --detach 0622a151c17180fa82ad58b2438c5c3d9574ad6d
  cd ./repo
  python3 -m venv .venv
  ./.venv/bin/pip install -q -e . && ./.venv/bin/pip install -q pytest httpx
intent: Ensure a request whose Authorization header uses the wrong scheme is rejected with a 401 naming Bearer in WWW-Authenticate and with no part of the submitted credential echoed back
pretest: |
  cd ./repo
  test -x ./.venv/bin/python || exit 3
  ./.venv/bin/python -c "import fastapi, fastapi.testclient" || exit 3
  ./.venv/bin/python "${BENCH_REPO_ROOT}/bench/fixtures/oracles/fastapi_bearer_401.py"
acceptance: |
  1. A wrong-scheme Authorization header yields HTTP 401.
  2. The 401 carries a `WWW-Authenticate` header naming `Bearer`.
  3. Neither the raw credential nor its base64 form appears in the body or in any response
     header.
  4. The repository's own test suite is green.
oracle: |
  cd ./repo
  ./.venv/bin/python "${BENCH_REPO_ROOT}/bench/fixtures/oracles/fastapi_bearer_401.py"
  ./.venv/bin/python -m pytest -q -x tests
notes: |
  `verified: true` means the pinned SHA was confirmed to exist by `git ls-remote` on
  2026-08-06. Criteria 1 and 2 may already hold at the pin; criterion 3 is the security core.
  `pretest` reports exit 0 (already satisfied) honestly rather than pretending the task is
  open, and exit 3 when the FastAPI test stack cannot be imported at that commit.
---

# T-022 — an auth rejection that says nothing

## Context

`OAuth2PasswordBearer` with `auto_error` rejects a malformed or wrong-scheme Authorization
header. What that rejection says back to the caller is the security question.

## Why this task

Echoing a rejected credential is how secrets end up in logs, error trackers, and support
tickets. It is also the kind of thing a diff review calls "helpful error messages". The
oracle searches the whole response -- body and every header -- for the secret.

## Grading

`bench/fixtures/oracles/fastapi_bearer_401.py` plus the repository suite.
