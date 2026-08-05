"""Tiny todo CLI used as the AIDD dogfood target."""


def add(items, text):
    if not text.strip():
        raise ValueError("empty todo")
    return items + [text.strip()]


def render(items):
    out = ""
    for i, t in enumerate(items):
        if out:
            out = out + "\n"
        out = out + f"{i + 1}. {t}"
    return out
