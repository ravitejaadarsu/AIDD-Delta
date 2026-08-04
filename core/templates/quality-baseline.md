# Quality baseline — <UTC-stamp> (<tag>)

<!-- Produced by build-snapshot.sh; do not hand-edit. Written to .aidd/context/quality-baseline.md. -->

## Test files

```
$ <command>
<count of test/spec files>
[exit <code>] <ISO-8601 timestamp>
```

## Repo size (tracked files)

```
$ <command>
<tracked file count>
[exit <code>] <ISO-8601 timestamp>
```

## Largest files (complexity hotspots proxy)

```
$ <command>
<top 10 files by line count>
[exit <code>] <ISO-8601 timestamp>
```

## TODO/FIXME markers

```
$ <command>
<count of TODO/FIXME occurrences>
[exit <code>] <ISO-8601 timestamp>
```

## Coverage

coverage: na (no canonical command available to this script)

<!-- ALWAYS present. The script never runs project commands, so it emits the explicit
     `na` row plus — when architecture.md names a canonical coverage command — a pointer
     saying the orchestrator appends the measured evidence block (`protocol/evidence.md`)
     to this section. A sigma it cannot measure is visible, never silently absent. -->

## Lint

lint: na (no canonical command available to this script)

<!-- Same contract as Coverage above. -->

Project-specific sigmas (coverage %, lint, mutation) come from the canonical
commands in architecture.md when a change is active; this script never runs them
(zero-dep), so the two sections above carry an explicit `na` row until the
orchestrator appends the measured evidence block — degradation is explicit.
