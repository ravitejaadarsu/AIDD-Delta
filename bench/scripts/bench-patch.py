#!/usr/bin/env python3
"""Exact, self-verifying text edits for defect injection.

Usage:
  bench-patch.py <file> --expect <text> --replace <text>
  bench-patch.py <file> --append-file <path>
  bench-patch.py <file> --copy-from <path>

Every mode fails loudly rather than half-applying:

  * `--expect` must occur EXACTLY ONCE in the target. Zero occurrences means the tree
    drifted from what the defect was written against; more than one means the anchor is
    ambiguous. Both exit 3, which `bench-inject.sh` reports as INJECT-FAIL.
  * `--append-file` and `--copy-from` require the source to exist (exit 3 otherwise).

Exit 0 on a successful edit, 2 on a usage error, 3 on a precondition failure. Stdlib only
(ADR 002). Injection is reverted by git, never by this script.
"""

import os
import sys


def die(code, msg):
    print(msg, file=sys.stderr)
    raise SystemExit(code)


def read(path):
    if not os.path.isfile(path):
        die(3, f"precondition: {path} does not exist")
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def write(path, text):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


def parse(argv):
    if len(argv) < 4:
        die(2, __doc__.strip().splitlines()[2].strip())
    target, flag = argv[1], argv[2]
    if flag == "--expect":
        if len(argv) != 6 or argv[4] != "--replace":
            die(2, "usage: bench-patch.py <file> --expect <text> --replace <text>")
        return target, "expect", (argv[3], argv[5])
    if flag in ("--append-file", "--copy-from"):
        if len(argv) != 4:
            die(2, f"usage: bench-patch.py <file> {flag} <path>")
        return target, flag.lstrip("-"), (argv[3],)
    die(2, f"unknown mode {flag!r}")
    return None  # unreachable; keeps linters quiet


def main(argv):
    if len(argv) == 2 and argv[1] in ("-h", "--help"):
        print(__doc__.strip())
        return 0
    target, mode, args = parse(argv)

    if mode == "expect":
        expect, replace = args
        text = read(target)
        count = text.count(expect)
        if count == 0:
            die(3, f"precondition: anchor not found in {target}: {expect!r}")
        if count > 1:
            die(3, f"precondition: anchor occurs {count} times in {target} (must be unique)")
        write(target, text.replace(expect, replace))
        print(f"patched {target}: 1 occurrence replaced")
        return 0

    source = read(args[0])
    if mode == "append-file":
        write(target, read(target) + source)
        print(f"patched {target}: appended {len(source)} bytes from {args[0]}")
        return 0

    parent = os.path.dirname(os.path.abspath(target))
    if not os.path.isdir(parent):
        die(3, f"precondition: {parent} does not exist")
    write(target, source)
    print(f"patched {target}: replaced with {args[0]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
