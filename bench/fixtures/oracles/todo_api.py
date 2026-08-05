#!/usr/bin/env python3
"""Deterministic oracles for the offline `sample-project` bench tasks.

Usage: todo_api.py <check>

Run from a task work directory (CWD contains ./src and ./tests). Exit 0 means the
task's acceptance criteria hold; any non-zero exit is a FAIL with the reason on
stderr. Zero third-party dependencies (ADR 002).

Graders live here rather than inline in the task frontmatter so they are committed,
reviewable, and unchanged across arms and reps (bench/harness.md, anti-cheating rule 3).
"""

import doctest
import importlib
import os
import shutil
import sys
import tempfile
import threading

sys.path.insert(0, os.path.join(os.getcwd(), "src"))


def fail(msg):
    print(f"ORACLE FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)


def need(cond, msg):
    if not cond:
        fail(msg)


def load(name):
    try:
        return importlib.import_module(name)
    except Exception as exc:  # noqa: BLE001 - any import problem is a FAIL
        fail(f"cannot import {name} from ./src ({exc!r})")


def raises(exc_type, fn, *args, **kwargs):
    try:
        fn(*args, **kwargs)
    except exc_type:
        return True
    except BaseException as other:  # noqa: BLE001 - wrong exception type is a FAIL
        fail(f"expected {exc_type.__name__}, got {other!r}")
    return False


# --- checks -----------------------------------------------------------------


def check_complete():
    todo = load("todo")
    need(hasattr(todo, "complete"), "todo.complete is not defined")
    items = todo.add([], "a")
    done = todo.complete(items, 0)
    need(todo.render(done) == "1. [x] a", f"render after complete was {todo.render(done)!r}")
    need(todo.render(items) == "1. a", "complete() mutated its input list")
    need(todo.render(todo.add([], "b")) == "1. b", "an undone item must render unprefixed")
    need(raises(IndexError, todo.complete, items, 5), "out-of-range index must raise IndexError")
    need(raises(IndexError, todo.complete, items, -9), "negative out-of-range must raise IndexError")


def check_remove():
    todo = load("todo")
    need(hasattr(todo, "remove"), "todo.remove is not defined")
    items = ["a", "b"]
    need(todo.remove(items, 0) == ["b"], "remove(items, 0) must drop the first item")
    need(items == ["a", "b"], "remove() mutated its input list")
    need(raises(IndexError, todo.remove, items, 5), "out-of-range index must raise IndexError")


def check_add_none():
    todo = load("todo")
    need(raises(ValueError, todo.add, [], None), "add(items, None) must raise ValueError")
    need(raises(ValueError, todo.add, [], "   "), "add(items, whitespace) must still raise ValueError")
    need(todo.add([], "a") == ["a"], "add() must still accept a valid item")


def check_render_newline():
    todo = load("todo")
    out = todo.render(["a\nb"])
    need(len(out.split("\n")) == 1, f"one item must render as one line, got {out!r}")
    need("a" in out and "b" in out, f"the item text must survive escaping, got {out!r}")
    need(todo.render(["a", "b"]) == "1. a\n2. b", "existing render output must not change")


def check_format_line():
    todo = load("todo")
    need(hasattr(todo, "_format_line"), "todo._format_line helper is not defined")
    need(todo._format_line(0, "a") == "1. a", "_format_line(0, 'a') must return '1. a'")
    need(todo.render(["a", "b"]) == "1. a\n2. b", "refactor changed render() output")


def check_save_traversal():
    todo = load("todo")
    need(hasattr(todo, "save"), "todo.save is not defined")
    base = tempfile.mkdtemp()
    outside = tempfile.mkdtemp()
    try:
        todo.save(["a", "b"], base, "list.txt")
        path = os.path.join(base, "list.txt")
        need(os.path.isfile(path), "save() did not write <base>/list.txt")
        with open(path, encoding="utf-8") as fh:
            need("a" in fh.read(), "save() wrote no item text")
        for evil in ("../escape", "a/../../escape", "/tmp/escape", "sub/../../escape"):
            need(raises(ValueError, todo.save, ["x"], base, evil), f"save() accepted {evil!r}")
        need(not os.path.exists(os.path.join(outside, "escape")), "save() wrote outside base")
        need(not os.path.exists(os.path.join(os.path.dirname(base), "escape")),
             "save() escaped its base directory")
    finally:
        shutil.rmtree(base, ignore_errors=True)
        shutil.rmtree(outside, ignore_errors=True)


def check_migrate():
    todo = load("todo")
    need(hasattr(todo, "migrate"), "todo.migrate is not defined")
    got = todo.migrate(["a"])
    need(got == [{"text": "a", "done": False}], f"legacy migration produced {got!r}")
    already = [{"text": "a", "done": True}]
    need(todo.migrate(already) == already, "migrate() must be idempotent and lossless")
    need(todo.render(["a"]) == "1. a", "render() must still accept legacy string items")
    need(todo.render([{"text": "a", "done": True}]) == "1. [x] a",
         "render() must accept record items and mark done ones")


def check_doctest():
    src = os.path.join(os.getcwd(), "src", "todo.py")
    need(os.path.isfile(src), "./src/todo.py is missing")
    todo = load("todo")
    for fn in ("add", "render"):
        obj = getattr(todo, fn, None)
        need(obj is not None, f"todo.{fn} is missing")
        need(obj.__doc__ and ">>>" in obj.__doc__, f"todo.{fn} has no doctest example")
    finder = doctest.DocTestFinder()
    examples = sum(len(t.examples) for t in finder.find(todo))
    need(examples >= 4, f"expected at least 4 doctest examples, found {examples}")
    result = doctest.testmod(todo, verbose=False)
    need(result.failed == 0, f"{result.failed} doctest example(s) failed")


def check_store_race():
    store = load("store")
    need(hasattr(store, "append_item"), "store.append_item is not defined")
    for attempt in range(1, 6):
        work = tempfile.mkdtemp()
        path = os.path.join(work, "items.txt")
        try:
            threads = [
                threading.Thread(target=lambda n=n: [store.append_item(path, f"t{n}-{i}") for i in range(100)])
                for n in range(8)
            ]
            for t in threads:
                t.start()
            for t in threads:
                t.join()
            got = len(store.load(path))
            need(got == 800, f"attempt {attempt}: expected 800 items after concurrent appends, got {got}")
        finally:
            shutil.rmtree(work, ignore_errors=True)


CHECKS = {
    "complete": check_complete,
    "remove": check_remove,
    "add-none": check_add_none,
    "render-newline": check_render_newline,
    "format-line": check_format_line,
    "save-traversal": check_save_traversal,
    "migrate": check_migrate,
    "doctest": check_doctest,
    "store-race": check_store_race,
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
