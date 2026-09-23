# ADR 022 — Source-bound execution receipts

**Decision.** New change templates enable receipts-v1. G1 binds a structured requirement set;
QA records explicit argv execution with source and output hashes; a manifest must cover every
approved criterion plus the final suite. The existing delivery preflight verifies these
receipts. Capture is opt-in host execution with bounded time/output and POSIX group cleanup.
Add read-only setup diagnostics and standalone HTML/JSON export without network calls.

**Why.** Artifact approval hashes do not catch product edits made after tests, omitted ACs,
or output records disconnected from execution. A small portable runner gives deterministic
checks that can be used with existing test tools and different agents. Parsing prose and
executing report commands would create ambiguity and unnecessary risk. Another review layer
would not provide a source fingerprint or reproducible receipt contract.

**Consequence.** New changes need structured requirements and final receipts; legacy changes
remain readable with a warning. Python 3.9+, Git and POSIX are needed for capture. Source
scope excludes root .aidd, ignored files and external state. Full hashing costs local I/O;
submodules and external symlinks block. Receipts are unsigned and do not establish semantic
correctness or independent authenticity. Tool callers own execution permissions, isolation
and secret handling. Future trusted CI must pin its checker separately from reviewed code.
