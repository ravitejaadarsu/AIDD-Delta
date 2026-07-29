# ADR 002 — YAML state + zero-dependency validator (no bats/PyYAML)

**Decision.** State files are a strict YAML subset validated by
`core/scripts/aidd-validate.py` (pure python3 stdlib: subset YAML parser + subset JSON
Schema checker). Self-tests are plain bash suites under `tests/`, not bats.
**Why.** Target machines (including this repo's dev machine) cannot be assumed to have
PyYAML, jsonschema, or bats; the framework promises zero-dependency operation everywhere
an agent CLI runs. YAML (not JSON) because gate approvals may be recorded by hand-editing
state on CLIs without command systems.
**Consequence.** State files must stay within the documented subset (block style, 2-space
indent, no anchors/flow/multiline); schemas restrict themselves to the supported keyword
subset. CI additionally runs shellcheck + markdownlint when available.
