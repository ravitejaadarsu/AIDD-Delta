# Verification recipes by use case

The receipt runner accepts explicit argv, so the same mechanism works with different stacks.
The commands below are examples to adapt, not automatically executed defaults. Inspect project
scripts first. Review [proof scope and limitations](execution-receipts.md) before relying on
receipts. These recipes are guidance, not evaluated claims about every technology listed.

| Use case | Command shape to capture | Evidence the reviewer must demand |
|---|---|---|
| Python service | `python3 -m unittest discover -s tests` | Happy path, negative cases and changed ACs |
| Node API / SDK | `npm test -- --run` (only when supported by its test runner) | Schema, status codes, backward compatibility |
| Browser UI | `npx --no-install playwright test` | Keyboard, error/loading states and responsive behavior; retain traces separately |
| Go service | `go test ./...` | Error paths, contract cases; race run where supported |
| Rust library | `cargo test --locked` | Public API and edge-case regressions |
| Auth / multi-tenancy | Explicit project negative-test command | Cross-role and cross-tenant rejection with real scoping |
| Database migration | Disposable-database migration test command | Up/down, representative rows and invariant checks |
| Infrastructure | Validation/plan against an isolated fixture | Resource diff and recovery path; no automatic apply |
| Data pipeline | Fixture transformation test command | Schema, nulls, duplicates, idempotency and data loss |
| Documentation | Project link checker / executable examples | Broken references and examples; avoid a fake green `echo` |
| Concurrency / performance | Seeded load or race harness | Repeat runs, thresholds and environment metadata |

Wrap the chosen argv using `aidd-evidence.py capture`; do not paste prose from this table into
a shell. Keep unit checks and integration checks separate so a receipt identifies exactly
what ran. An unavailable service is a blocker or an explicitly allowed degradation, never
a passing test. Native tool reports remain useful alongside receipts; the runner intentionally
does not parse every test framework or substitute for its assertions.

For a change spanning several rows, keep one approved requirement set and map each criterion
to the relevant receipts. The full-suite receipt protects regression coverage; individual
criterion receipts explain the behavior. Their correctness still requires human/agent review.
