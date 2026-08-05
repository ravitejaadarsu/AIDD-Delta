"""Deliberately racy item store — bench seed for T-011.

Copied into the task work dir as ./src/store.py by that task's `setup`. The
read-modify-write in `append_item` has no lock, so concurrent callers lose items:
each thread reads the whole list, appends one entry, and rewrites the file, so
whichever writer lands last erases every entry written since it read.

This file is a benchmark input, not framework code. Do not "fix" it here — the fix
belongs in the task work dir, which is what the task measures.
"""

import os
import threading


def load(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as fh:
        return [line for line in fh.read().split("\n") if line]


def append_item(path, text):
    items = load(path)
    items.append(text)
    tmp = f"{path}.{os.getpid()}.{threading.get_ident()}.tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write("\n".join(items) + "\n" if items else "")
    os.replace(tmp, path)
