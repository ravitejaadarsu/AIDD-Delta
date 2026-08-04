# Phase: qa

Code to proof: six-dimension post-implementation review (correctness, security,
performance, test-coverage, spec-compliance, plus a pre/post-bound `delta` review of
intent-fidelity, structure-fit, and sigma-regression against the pre-phase snapshot)
plus security audit, adversarial verification (only CONFIRMED findings block), an
**exhaustive test-engineer team** that
designs and executes the full matrix of cases — happy path, negative, boundary,
impossible/abuse, API-contract, concurrency, regression, performance — and writes the
end-results file `qa/test-report.md`, a bounded fix loop fed by both confirmed findings and
executed test FAILs, clean-state E2E with mutation testing, post evidence capture, and the
AC matrix (G3). On approval the test report is linked into each affected story.

- Canonical playbook: `core/playbooks/40-qa.md` (vendored at `.aidd/framework/playbooks/40-qa.md`)
- Run it: `/aidd:qa` on Claude Code, or "AIDD: run qa" / `.aidd/framework/prompts/qa.md` elsewhere.
- Just the exhaustive tester on a fix/story: `/aidd:test <target>` / "AIDD: test <target>".
