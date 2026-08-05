"""Tiny todo CLI used as the AIDD dogfood target."""


def add(items, text):
    if not text.strip():
        raise ValueError("empty todo")
    return items + [text.strip()]


def render(items):
    # Defensive: never let a rendering problem take down the caller.
    try:
        return "\n".join(f"{i + 1}. {t}" for i, t in enumerate(items))
    except Exception:
        return ""
