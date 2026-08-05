#!/usr/bin/env python3
"""Assert no function in a Python file exceeds a line limit.

Usage: max_func_lines.py <file.py> <limit>

Exit 0 when every function and method body fits the limit, 1 when one does not (with the
offenders on stderr), 2 on a usage error, 3 when the file is missing or unparseable — the
precondition code the harness records as an `error` rather than a FAIL (bench/harness.md).

Used as the deterministic grader for behaviour-preserving refactor tasks: the structural
obligation is measurable, so the oracle never has to judge style. Stdlib only (ADR 002).
"""

import ast
import os
import sys


def main(argv):
    if len(argv) == 2 and argv[1] in ("-h", "--help"):
        print(f"usage: {os.path.basename(argv[0])} <file.py> <limit>")
        return 0
    if len(argv) != 3:
        print(f"usage: {os.path.basename(argv[0])} <file.py> <limit>", file=sys.stderr)
        return 2
    path, raw_limit = argv[1], argv[2]
    try:
        limit = int(raw_limit)
    except ValueError:
        print(f"limit must be an integer, got {raw_limit!r}", file=sys.stderr)
        return 2
    if not os.path.isfile(path):
        print(f"precondition: {path} does not exist", file=sys.stderr)
        return 3
    try:
        with open(path, encoding="utf-8") as fh:
            tree = ast.parse(fh.read(), filename=path)
    except SyntaxError as exc:
        print(f"precondition: cannot parse {path} ({exc})", file=sys.stderr)
        return 3

    offenders = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            end = getattr(node, "end_lineno", None)
            if end is None:
                print(f"precondition: no end_lineno on {node.name}", file=sys.stderr)
                return 3
            span = end - node.lineno + 1
            if span > limit:
                offenders.append((node.name, node.lineno, span))

    if offenders:
        for name, line, span in sorted(offenders, key=lambda o: -o[2]):
            print(f"{path}:{line}: {name} spans {span} lines (limit {limit})", file=sys.stderr)
        return 1
    print(f"ORACLE PASS: every function in {path} fits {limit} lines")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
