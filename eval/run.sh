#!/usr/bin/env bash
# Planted-fixture eval for the a11y-audit skill.
#
# Tier 1 (default, free, ~1-2 min): serves eval/fixtures/planted.html locally,
#   runs the skill's own scan.sh + merge_findings.py against it, and asserts the
#   planted defects appear in findings.json. Catches script/scanner regressions.
#
# Tier 2 (--e2e, one full model run, several minutes): additionally spawns
#   `claude -p` with the SKILL.md and grades the resulting report for every
#   planted defect, including the filename-as-alt catch that only the model
#   judgment layer can make. Run before tagging a release.
#
# Usage:
#   eval/run.sh           # tier 1 only
#   eval/run.sh --e2e     # tier 1 + tier 2
#
# Requires: node/npx (pa11y), python3. Tier 2 requires the `claude` CLI logged in.
# NOTE: tier 2 runs claude with --dangerously-skip-permissions so the headless
# session can execute the skill's scan scripts. It is pointed at a local fixture
# and a scratch output dir; review the prompt below before repurposing.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$REPO/skills/a11y-audit"
PORT="${PORT:-8917}"
OUT="${OUT:-$(mktemp -d /tmp/a11y-eval.XXXXXX)}"
URL="http://127.0.0.1:$PORT/planted.html"

echo "== a11y-audit eval =="
echo "fixture: $URL"
echo "output:  $OUT"

python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$REPO/eval/fixtures" >/dev/null 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
sleep 1
curl -sf "$URL" >/dev/null || { echo "FAIL: fixture server did not come up on :$PORT"; exit 1; }

echo
echo "-- tier 1: scanner pipeline --"
bash "$SKILL/scripts/scan.sh" "$OUT" "$URL"
python3 "$SKILL/scripts/merge_findings.py" "$OUT"
TIER1=0
python3 "$REPO/eval/check.py" scanner "$OUT" || TIER1=$?

TIER2=0
if [ "${1:-}" = "--e2e" ]; then
  echo
  echo "-- tier 2: end-to-end via claude -p --"
  PROMPT="Read the skill file at $SKILL/SKILL.md and follow it to run an accessibility audit of $URL. This is a local single-page test fixture, not a Shopify store: skip sitemap sampling, Shopify attribution, and tracker filing, and audit only that one page. The skill's base directory is $SKILL and your scratch/output directory is $OUT. Write the final findings report as markdown to $OUT/report.md."
  claude -p "$PROMPT" --dangerously-skip-permissions > "$OUT/e2e-transcript.txt" 2>&1 || true
  python3 "$REPO/eval/check.py" report "$OUT/report.md" || TIER2=$?
fi

echo
if [ "$TIER1" -eq 0 ] && [ "$TIER2" -eq 0 ]; then
  echo "EVAL PASS ($OUT)"
else
  echo "EVAL FAIL ($OUT)"
  exit 1
fi
