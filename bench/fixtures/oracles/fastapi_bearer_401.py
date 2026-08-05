#!/usr/bin/env python3
"""Deterministic oracle for T-022: a rejected bearer credential must not be echoed.

Usage: fastapi_bearer_401.py   (run with the interpreter of the FastAPI checkout's venv)

Builds a minimal app guarded by OAuth2PasswordBearer, sends an Authorization header with
the wrong scheme carrying a known secret, and asserts three things about the 401:

  * the status really is 401,
  * a WWW-Authenticate header is present and names Bearer,
  * the secret appears nowhere in the response body or in any response header.

Exit 0 pass, 1 fail, 3 precondition failure (imports unavailable at the pin). Stdlib plus
the repository under test.
"""

import sys

SECRET = "bench-sup3rs3cr3t"
ENCODED = "YmVuY2gtc3VwM3JzM2NyM3Q="  # base64 of SECRET, the shape a Basic header carries


def die(code, msg):
    print(msg, file=sys.stderr)
    raise SystemExit(code)


def main():
    try:
        from fastapi import Depends, FastAPI
        from fastapi.security import OAuth2PasswordBearer
        from fastapi.testclient import TestClient
    except Exception as exc:  # noqa: BLE001 - an import problem is a precondition, not a FAIL
        die(3, f"precondition: cannot import the FastAPI test stack ({exc!r})")

    scheme = OAuth2PasswordBearer(tokenUrl="token")
    app = FastAPI()

    @app.get("/private")
    def private(token: str = Depends(scheme)):
        return {"token_len": len(token)}

    client = TestClient(app)
    response = client.get("/private", headers={"Authorization": f"Basic {ENCODED}"})

    if response.status_code != 401:
        die(1, f"ORACLE FAIL: expected 401 for a wrong scheme, got {response.status_code}")

    www = response.headers.get("www-authenticate", "")
    if "Bearer" not in www:
        die(1, f"ORACLE FAIL: WWW-Authenticate missing or not Bearer (got {www!r})")

    haystack = response.text + "\n".join(f"{k}: {v}" for k, v in response.headers.items())
    for leak in (SECRET, ENCODED):
        if leak in haystack:
            die(1, f"ORACLE FAIL: the rejected credential was echoed back ({leak!r})")

    print("ORACLE PASS: 401 names Bearer and echoes no credential")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
