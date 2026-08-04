# ADR 007 — A repo-level context snapshot replaces per-agent crawling

**Decision.** A repo-level, gitignored context pack (`.aidd/context/`) replaces
per-agent repo crawling. It is rebuilt at every phase boundary and after every
Construction wave, and every role reads it FIRST instead of re-deriving the same
repo-tree, module-map, and quality-baseline facts independently.
**Why.** Every role re-scanning the repo from scratch burns context window on
redundant discovery and risks each agent forming a slightly different picture of the
same ground truth. A single shared pack gives every dispatch the same facts at the
same moment, cheaply.
**Consequence.** One rebuild per phase boundary and per wave — a small, bounded cost.
Packs are disposable: never trusted across a resume, never hashed into a gate, always
rebuilt before the next read. A missing pack degrades a role's context, not its
correctness — the role proceeds and notes the degradation rather than blocking.
