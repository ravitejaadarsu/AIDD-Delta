# ADR 001 — The portable core is the product

**Decision.** All phase logic, roles, protocol, templates, and schemas live in `core/`
as plain markdown/YAML/JSON. The Claude Code plugin is a thin shell of pointers.
**Why.** The user requires Codex CLI (and any agent CLI) parity. Two sources of phase
logic would drift; one portable source cannot.
**Consequence.** Claude-specific power (parallel Task fan-out, hooks) is additive, never
semantic: sequential fallback must converge on identical artifacts.
