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

Project-specific sigmas (coverage %, lint, mutation) come from the canonical
commands in architecture.md when a change is active; absent that, rows above
are the baseline and missing sigmas are explicit `na` (degradation is explicit).
