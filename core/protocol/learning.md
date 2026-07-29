# Learning Protocol

Every run makes the next run smarter.

## Retro (after Delivery)

The Retro Learner mines the completed change for:

- Review findings that were REFUTED (reviewer over-flagging patterns to damp).
- take-care assumptions that proved wrong (question-asking patterns to sharpen).
- Fix-loop root causes (construction patterns to avoid).
- Supervision violations (process steps that need reinforcement).
- Friction events (missing commands, flaky verification, unclear templates).
- Memory health: stale or contradicted lessons, and citations whose evidence artifact no longer exists.

## learnings.md format

Append-only, deduplicated by the Learner before writing:

```markdown
## L-014 — <one-line lesson>
- context: <change-id, phase>
- rule: <imperative guidance a future agent can apply directly>
- evidence: <artifact reference>
```

## Load points

- Master phase loads `learnings.md` into the constitution interview context.
- Inception's Product Analyst and Architect read it before generating.
- The Post-Impl Reviewers read damping lessons to avoid re-raising refuted classes.

Lessons are advisory context, never overrides of the constitution or protocol.
