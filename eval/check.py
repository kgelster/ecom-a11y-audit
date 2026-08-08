#!/usr/bin/env python3
"""Graders for the planted-fixture eval. Deterministic; no network, no model calls.

Usage:
    check.py scanner OUTDIR       # tier 1: assert findings.json caught the planted defects
    check.py report REPORT.md     # tier 2: assert the model's report caught them

Exit 0 = all assertions pass, exit 1 = at least one failed (details on stdout).
"""
import json
import os
import re
import sys

EXPECTED = os.path.join(os.path.dirname(os.path.abspath(__file__)), "expected.json")


def load_expected():
    with open(EXPECTED) as f:
        return json.load(f)


def check_scanner(outdir):
    path = os.path.join(outdir, "findings.json")
    if not os.path.isfile(path):
        print(f"FAIL: {path} not found (did scan.sh + merge_findings.py run?)")
        return 1
    with open(path) as f:
        findings = json.load(f)
    if findings.get("unscanned_pages"):
        print(f"FAIL: unscanned pages: {findings['unscanned_pages']}")
        return 1
    # a planted rule may surface as a violation or (htmlcs variants) in the judgment queue
    seen = set()
    for entry in findings.get("violations", []) + findings.get("judgment_queue", []):
        seen.add(entry.get("rule", ""))
    failures = 0
    for planted in load_expected()["scanner_rules"]:
        hits = [r for r in planted["rules"] if any(r in s for s in seen)]
        if hits:
            print(f"PASS  {planted['id']} (SC {planted['sc']}): caught as {hits}")
        else:
            print(f"FAIL  {planted['id']} (SC {planted['sc']}): none of {planted['rules']} in scan output")
            failures += 1
    print(f"\nscanner tier: {'PASS' if failures == 0 else f'{failures} FAILED'}")
    return 1 if failures else 0


def check_report(report_path):
    if not os.path.isfile(report_path):
        print(f"FAIL: report not found at {report_path}")
        return 1
    with open(report_path, encoding="utf-8", errors="replace") as f:
        text = f.read()
    if len(text.strip()) < 200:
        print(f"FAIL: report is {len(text.strip())} chars; the run likely died before writing it")
        return 1
    expected = load_expected()
    failures = 0
    for planted in expected["report_patterns"]:
        hit = next((p for p in planted["patterns"]
                    if re.search(p, text, re.IGNORECASE)), None)
        if hit:
            print(f"PASS  {planted['id']}: matched /{hit}/")
        else:
            print(f"FAIL  {planted['id']}: no pattern of {planted['patterns']} in report")
            failures += 1
    for pat in expected["forbidden_patterns"]:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            print(f"FAIL  forbidden claim present: {m.group(0)!r}")
            failures += 1
    print(f"\nreport tier: {'PASS' if failures == 0 else f'{failures} FAILED'}")
    return 1 if failures else 0


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("scanner", "report"):
        print(__doc__)
        return 2
    if sys.argv[1] == "scanner":
        return check_scanner(sys.argv[2])
    return check_report(sys.argv[2])


if __name__ == "__main__":
    sys.exit(main())
