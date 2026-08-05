#!/usr/bin/env bash
# Claims conformance: the project's honesty surface is mechanical, not cultural.
# A claim that outruns its evidence should fail CI, not survive review. This suite asserts
# the README carries its honest-status block and no absolute-claim boilerplate, that every
# capability-matrix row states a value for all three tiers (ADR 015), and that the adoption
# on-ramp keeps demanding verifiable evidence. Fast and fully offline.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
fail=0

need() { # file, extended-regex, what-it-must-do
  if ! grep -qE "$2" "$1"; then
    echo "FAIL: $1 must $3 (/$2/)"
    fail=1
  fi
}

# ── README: the honest-status block and the claim taxonomy.
R=README.md
need "${R}" '^## Status: honest$'                  "carry the '## Status: honest' block"
need "${R}" 'no published benchmark results yet'   "state that no benchmark results are published yet"
need "${R}" 'pre-1\.0'                             "state pre-1.0 status"
need "${R}" 'single author'                        "state single authorship"
need "${R}" 'none yet'                             "state that external validation is absent"
need "${R}" 'tests/run\.sh'                        "point at the self-test suite"
need "${R}" '\*\*\[designed\]\*\*'                 "label designed claims"
need "${R}" '\*\*\[measured\]\*\*'                 "label measured claims"
need "${R}" '\*\*\[planned\]\*\*'                  "label planned claims"
need "${R}" '\*\*\[Tier 1\]\*\*'                   "badge Tier-1-only capabilities"
need "${R}" '\*\*\[all tiers\]\*\*'                "badge all-tier capabilities"
need "${R}" 'docs/capability-matrix\.md'           "link the capability matrix"
need "${R}" 'docs/rigor-modes\.md'                 "link the rigor-mode cost story"

python3 - <<'PY' || fail=1
import re, sys

errors = []

def read(path):
    try:
        with open(path, encoding='utf-8') as fh:
            return fh.read()
    except OSError as exc:
        errors.append(f"{path}: cannot read ({exc})")
        return ""

# ── 1. README must not carry unqualified absolute claims.
readme = read('README.md')
low = readme.lower()

DENY = [
    "guarantees bug-free", "guarantee bug-free", "guaranteed bug-free",
    "zero defects", "zero bugs", "100% coverage", "100 % coverage",
    "battle-tested", "battle tested", "industry-leading", "industry leading",
    "best-in-class", "world-class", "flawless", "bulletproof",
]
for phrase in DENY:
    if phrase in low:
        errors.append(f"README.md: forbidden absolute claim {phrase!r}")

# "production-ready" is allowed only when the same line disclaims it.
QUALIFIERS = ("not production-ready", "not production ready", "not yet production")
for m in re.finditer(r'production[- ]ready', low):
    start = low.rfind('\n', 0, m.start()) + 1
    end = low.find('\n', m.end())
    line = low[start:end if end != -1 else len(low)]
    if not any(q in line for q in QUALIFIERS):
        errors.append("README.md: 'production-ready' used without a qualifier")

# No star / fork / adopter counts — there are none to report.
COUNT_RE = re.compile(
    r'\b\d[\d,.]*\s*(?:\+\s*)?(?:github\s+)?'
    r'(?:stars?|forks?|watchers?|adopters?|teams?|companies|organizations|'
    r'orgs|downloads|installs|users|contributors?)\b', re.I)
for m in COUNT_RE.finditer(readme):
    errors.append(f"README.md: adoption/star count claim {m.group(0)!r}")
for glyph in ("★", "⭐"):
    if glyph in readme:
        errors.append("README.md: star glyph implies a star count")

# ── 2. Every capability row must state a value for all three tiers (ADR 015).
MX = 'docs/capability-matrix.md'
matrix = read(MX)
parts = matrix.split('## Capabilities that differ', 1)
if len(parts) < 2:
    errors.append(f"{MX}: missing the '## Capabilities that differ' section")
else:
    body = parts[1].split('\n## ', 1)[0]
    lines = [ln.strip() for ln in body.splitlines() if ln.strip().startswith('|')]

    def cells(line):
        # Escaped pipes inside a cell (e.g. Write\|Edit) must not split the row.
        holder = line.replace(r'\|', '\x00').strip().strip('|')
        return [c.replace('\x00', '|').strip() for c in holder.split('|')]

    if len(lines) < 3:
        errors.append(f"{MX}: capability table has no data rows")
    else:
        header, separator, data = lines[0], lines[1], lines[2:]
        for tier in ('Tier 1', 'Tier 2', 'Tier 3'):
            if tier not in header:
                errors.append(f"{MX}: capability table header omits {tier}")
        if not set(separator) <= set('|-: '):
            errors.append(f"{MX}: expected a table separator row, got {separator!r}")
        data = [d for d in data if set(d) - set('|-: ')]
        if len(data) < 8:
            errors.append(f"{MX}: only {len(data)} capability rows; the matrix must cover "
                          "dispatch, each hook, the MCP integrations, the command surface "
                          "and background work")
        VALUE_RE = re.compile(r'\b(supported|degraded|unsupported)\b', re.I)
        for row in data:
            cs = cells(row)
            if len(cs) != 4:
                errors.append(f"{MX}: row has {len(cs)} cells, expected 4: {cs[:1]}")
                continue
            name = cs[0] or '<unnamed>'
            if not cs[0]:
                errors.append(f"{MX}: a capability row has an empty capability name")
            for idx, tier in enumerate(('Tier 1', 'Tier 2', 'Tier 3'), start=1):
                cell = cs[idx]
                if not cell:
                    errors.append(f"{MX}: '{name}' has no value for {tier}")
                elif not VALUE_RE.search(cell):
                    errors.append(f"{MX}: '{name}' / {tier} states no "
                                  "supported|degraded|unsupported value")

# ── 3. The case-study template must demand verifiable evidence.
TPL = 'docs/case-studies/TEMPLATE.md'
tpl = read(TPL)
for label, pattern in (
        ("token cost", r'token cost'),
        ("defects attributed by layer", r'defects caught by layer'),
        ("defects the framework missed", r'defects the framework missed'),
        ("artifact links", r'artifact links'),
        ("rigor mode", r'rigor mode'),
        ("run duration", r'run duration'),
        ("runtime and tier", r'runtime and tier'),
        ("what the framework got wrong", r'what the framework got wrong'),
):
    if not re.search(pattern, tpl, re.I):
        errors.append(f"{TPL}: must require {label}")

CS = 'docs/case-studies/README.md'
cs = read(CS)
if not re.search(r'unverifiable submissions are not published', cs, re.I):
    errors.append(f"{CS}: must say unverifiable submissions are not published")
if not re.search(r'negative results are welcome and published', cs, re.I):
    errors.append(f"{CS}: must say negative results are welcome and published")

# ── 4. CONTRIBUTING must state the tier-row + test + docs-page requirement.
CB = 'CONTRIBUTING.md'
cb = read(CB)
if not re.search(r'a tier row.*a test.*a docs page', cb, re.I | re.S):
    errors.append(f"{CB}: must require a tier row, a test, and a docs page for every "
                  "new capability")
for token in ('docs/capability-matrix.md', 'tests/run.sh', 'scripts/check-refs.sh'):
    if token not in cb:
        errors.append(f"{CB}: must name {token}")

# ── 5. The PR checklist must enforce suite-green and the capability-matrix row.
PR = '.github/PULL_REQUEST_TEMPLATE.md'
pr = read(PR)
checklist = []
for ln in pr.splitlines():
    if ln.strip().startswith('- [ ]'):
        checklist.append(ln.strip())
    elif checklist and ln.startswith(' ') and ln.strip() and not ln.strip().startswith('-'):
        checklist[-1] += ' ' + ln.strip()   # wrapped continuation of the item above
    elif not ln.strip():
        continue
if not checklist:
    errors.append(f"{PR}: has no checklist items")
for label, pattern in (
        ("suite green (tests/run.sh, failures=0)", r'tests/run\.sh|failures=0'),
        ("a capability-matrix row", r'capability-matrix\.md'),
        ("an ADR for design changes", r'\bADR\b'),
        ("docs updated", r'docs updated|docs/'),
):
    if not any(re.search(pattern, item, re.I) for item in checklist):
        errors.append(f"{PR}: checklist must include {label}")

# ── 6. The issue templates must ask for tier, runtime, rigor mode, artifact paths.
for path in ('.github/ISSUE_TEMPLATE/bug_report.md',
             '.github/ISSUE_TEMPLATE/case_study.md'):
    text = read(path)
    for label, pattern in (("tier", r'\btier\b'), ("runtime", r'runtime'),
                           ("rigor mode", r'rigor mode'),
                           ("artifact paths", r'artifact')):
        if not re.search(pattern, text, re.I):
            errors.append(f"{path}: must ask for {label}")

if errors:
    print('\n'.join(errors))
    sys.exit(1)
print('claims OK')
PY

exit "${fail}"
