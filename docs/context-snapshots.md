# Context Snapshots

Canonical: `core/protocol/context-snapshots.md`.

A repo-level context pack so every role reads instead of re-crawling the repo on every
dispatch. It lives under the gitignored `.aidd/context/` — never committed, never pushed —
and is rebuilt, not carried forward, at each point it matters.

- **Built by** `.aidd/framework/scripts/build-snapshot.sh <tag>`, which writes
  `snapshot.md` (repo tree, module map, entry points), `quality-baseline.md` (measured
  sigmas — test-file count, repo size, complexity hotspots, TODO/FIXME count — each with
  its command), and `delta.md` (churn since the previous snapshot), plus a gitignored
  `.last-ref` marker.
- **Rebuild cadence** — every phase boundary (tag `pre-<phase>`) and after every
  Construction wave (tag `post-wave-<n>`); orchestrator duty, wired into
  `core/playbooks/00-pipeline.md` and each phase playbook.
- **Consumption rule** — every role reads `snapshot.md` (and `quality-baseline.md` where
  relevant to its dimension) FIRST, before touching the live repo. A missing pack never
  blocks the role; it proceeds and notes the degradation explicitly.
- **Resume rule** — a snapshot is never trusted across a resume; it is rebuilt before
  continuing. Gates never pin snapshot hashes — the pack is a reading aid, not a
  verification artifact.
- **History trail** — every rebuild copies its three files to
  `.aidd/context/history/<UTC-stamp>-<tag>/`, so prior packs stay inspectable; the delta
  reviewer (`mode=delta`) compares the `pre-<phase>` history pack against the current one.
