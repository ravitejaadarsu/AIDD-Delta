"""Usage counters for the todo module.

Injected by D-010 as an uncommitted new file so that it appears in the change's diff while
belonging to no story's ownership set. Every line of it reviews fine in isolation; nobody
asked for it.
"""

_COUNTS = {}


def record(event):
    """Count one occurrence of `event`."""
    _COUNTS[event] = _COUNTS.get(event, 0) + 1
    return _COUNTS[event]


def snapshot():
    """Return a copy of the current counters."""
    return dict(_COUNTS)


def reset():
    """Clear every counter."""
    _COUNTS.clear()
