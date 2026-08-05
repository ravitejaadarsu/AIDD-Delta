#!/usr/bin/env python3
"""Deterministic oracles for the offline `sample-web` bench tasks.

Usage: web_page.py <check>

Run from a task work directory (CWD contains ./index.html). Exit 0 means the task's
acceptance criteria hold; any non-zero exit is a FAIL with the reason on stderr.
Stdlib only (ADR 002) — no browser, no network, so these run in CI.
"""

import os
import re
import sys


def fail(msg):
    print(f"ORACLE FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)


def need(cond, msg):
    if not cond:
        fail(msg)


def read(name):
    if not os.path.isfile(name):
        fail(f"{name} is missing")
    with open(name, encoding="utf-8") as fh:
        return fh.read()


def check_button_label():
    html = read("index.html")
    buttons = re.findall(r"<button\b[^>]*>(.*?)</button>", html, flags=re.S | re.I)
    need(len(buttons) == 1, f"expected exactly one button, found {len(buttons)}")
    need(buttons[0].strip() == "Start", f"button label is {buttons[0].strip()!r}, expected 'Start'")
    need(re.search(r"<button\b[^>]*\bid=[\"']go[\"']", html, flags=re.I),
         "the button id must stay 'go' — a copy change must not rename the hook")
    need("AIDD sample web" in html, "the page heading text must not change")


def check_csp_inline():
    html = read("index.html")
    meta = re.search(r"<meta\b[^>]*http-equiv=[\"']Content-Security-Policy[\"'][^>]*>", html, flags=re.I)
    need(meta is not None, "no Content-Security-Policy meta tag in index.html")
    need("script-src" in meta.group(0), "the CSP must constrain script-src")
    need("'unsafe-inline'" not in meta.group(0), "the CSP still allows 'unsafe-inline'")
    inline = [m for m in re.findall(r"<script\b([^>]*)>(.*?)</script>", html, flags=re.S | re.I)
              if m[1].strip()]
    need(not inline, f"index.html still carries {len(inline)} inline script block(s)")
    need(re.search(r"<script\b[^>]*src=[\"']\.?/?app\.js[\"']", html, flags=re.I),
         "index.html does not load app.js")
    need(not re.search(r"\bon[a-z]+=", html, flags=re.I), "index.html still has an inline event handler")
    app = read("app.js")
    need("getElementById" in app, "app.js does not reference the DOM nodes it must wire")
    need("Clicked" in app, "app.js must keep the original click behaviour")


CHECKS = {
    "button-label": check_button_label,
    "csp-inline": check_csp_inline,
}


def main(argv):
    if len(argv) != 2 or argv[1] in ("-h", "--help"):
        print(f"usage: {os.path.basename(argv[0])} <{'|'.join(sorted(CHECKS))}>")
        return 0 if len(argv) == 2 else 2
    check = CHECKS.get(argv[1])
    if check is None:
        print(f"unknown check {argv[1]!r}; known: {', '.join(sorted(CHECKS))}", file=sys.stderr)
        return 2
    check()
    print(f"ORACLE PASS: {argv[1]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
