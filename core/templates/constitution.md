# Project Constitution

The standing law of this repository. Every AIDD agent reads this before acting.
Filled in by the Master phase interview; edit anytime — changes apply to the next phase.

## Identity

- Project: <name>
- Stack: <languages, frameworks, package manager>
- Default branch: <main>

## Canonical commands

<!-- The Architect refines these per change; these are repo-level defaults. -->
- build: `<cmd>`
- test: `<cmd>`
- lint: `<cmd>`
- typecheck: `<cmd or n/a>`
- e2e: `<cmd or n/a>`

## Quality bars

- Test coverage target: <85>% (floor: target − 10)
- Mutation score floor: <60>% (`na` if no mutation tool exists for the stack)
- Performance budgets: <e.g. p95 endpoint latency 200ms; or n/a>
- Definition of Done: tests green · lint clean · docs updated · AC matrix all-PASS ·
  evidence captured pre+post · supervision compliant

## Standards

- Code style: <link or rules>
- Commit convention: Conventional Commits, grouped per story
- Security: no secrets in code; dependency audit must be clean of CRITICAL

## Integrations

- Jira write-back enabled: false
- CI provider: github-actions
