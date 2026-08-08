# Behavioral eval

CI (`validate-skills.yml`) proves the SKILL.md parses. This eval proves the skill
still *works*: a local fixture page with known, deliberate defects is audited, and
the output is graded against ground truth. Run it before tagging a release.

## Layout

- `fixtures/planted.html` — single page with 6 planted defects (5 machine-detectable,
  1 that only the model judgment layer can catch: `alt="DSC_0042.jpg"`). Every defect
  is marked with a `PLANTED:` comment. Don't fix them; the eval fails if they go away.
- `expected.json` — ground truth: scanner rule ids per defect (tier 1) and
  case-insensitive report regexes per defect plus forbidden compliance claims (tier 2).
- `run.sh` — serves the fixture on `127.0.0.1:8917`, runs the tiers, exits non-zero on failure.
- `check.py` — deterministic graders. No network, no model calls.

## Tiers

**Tier 1 — scanner pipeline (default, free, ~1-2 min).**
`run.sh` runs the skill's own `scan.sh` + `merge_findings.py` against the fixture and
asserts each planted defect appears in `findings.json` (violations or judgment queue).
Catches regressions in the scripts, a pa11y/axe behavior change, or a broken merge.

**Tier 2 — end-to-end (`--e2e`, one full model run, several minutes).**
Additionally spawns `claude -p` (logged-in CLI required) told to follow SKILL.md
against the fixture, then grades the written report: every planted defect must be
named, including the filename-as-alt catch scanners can't make, and the report must
not contain a compliance claim ("fully compliant", "no accessibility issues").
Runs with `--dangerously-skip-permissions` so the headless session can execute the
scan scripts; it is pointed only at the local fixture and a scratch dir.

```bash
eval/run.sh          # tier 1
eval/run.sh --e2e    # tier 1 + 2, before a release
```

Not wired into GitHub CI on purpose: tier 2 needs an authenticated `claude` CLI and
costs a real model run. This is an operator-run release gate.
