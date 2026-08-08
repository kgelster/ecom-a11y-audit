# a11y-audit

An accessibility audit skill for Shopify stores, built for Claude Code (and any agent runtime that reads `SKILL.md` skills). Point it at a storefront and it produces a prioritized WCAG 2.2 Level AA findings report: automated scanners for the deterministic checks, model judgment for everything scanners can't decide, honest labeling for everything neither could check, and every finding attributed to its real owner: the theme, or the app that injected the markup.

**Honesty is the product.** Automated rules cover roughly 20-40% of WCAG success criteria. This skill never claims compliance from a clean scan, never marks an unchecked criterion as a pass, and never invents a contrast ratio it didn't compute. Criteria that weren't exercised are reported as **Undetermined**, not passed.

**Attribution is the Shopify part.** On a real store, a large share of accessibility failures arrive with the apps: the cart-drawer upsell that hides focusable elements behind `aria-hidden`, the review widget's sub-24px tap targets, the untitled chat iframe, the tracking pixel's alt-less 1x1s. Telling a merchant to "fix the theme" for those wastes everyone's time. This skill fingerprints the failing DOM (Rebuy, Okendo, Klaviyo, Judge.me, Loox, Yotpo, Stamped, Privy, Attentive, Recharge, Gorgias, Tidio, page builders, payment iframes, and more), splits the report into theme-owned vs app-injected, and gives each app finding a fix route: widget settings, or a support ticket the merchant can forward verbatim.

## What it does

1. **Samples by theme template, not URL count.** A Shopify store renders thousands of URLs through a handful of templates. The skill reads the sitemap and audits one representative each of home, PDP, collection, article, content page, and cart (search and 404 on thorough runs), picking the most app-heavy PDP rather than the sparsest. Checkout is Shopify-hosted and locked; it's reported as out of scope, never silently passed.
2. **Scans with two engines at once.** `scripts/scan.sh` runs pa11y with both axe-core and HTML_CodeSniffer in a single Puppeteer instance, plus optional Lighthouse for the familiar 0-100 score. Pinned majors (`pa11y@9`, `lighthouse@13`), no global installs.
3. **Compresses before the model reads anything.** `scripts/merge_findings.py` normalizes both engines' output to WCAG success criteria, dedups cross-engine, caps evidence samples, tags every node with its suspected owner, and splits hard violations from a judgment queue. A 6-page scan produces ~9MB of raw JSON; the model reads ~36KB. Raw scanner JSON never enters context. Pages whose scan failed are surfaced as UNSCANNED, never mistaken for clean.
4. **Adds the model pass scanners can't do.** Alt text *quality* (not just presence), useless link names, contrast indeterminates over hero imagery, readability (advisory), semantic HTML, and triage of the high-false-positive HTML_CodeSniffer warning queue.
5. **Runs the usability half, not just the markup half.** Scanners can't tab through a page; the agent can. The interactive pass drives the storefront through claude-in-chrome or Playwright: `scripts/focus_probe.js` (injected in-page, zero dependencies) maps the real tab order and catches focusables inside `aria-hidden` UI, invisible tab stops (off-canvas carousel clones, hidden popups), missing skip links, and suppressed focus indicators; real Tab/Escape key checks then prove or refute traps and modal focus behavior, and a 320px resize checks reflow. The report still says plainly what a driven browser cannot cover: screen reader announcement and lived assistive-tech experience stay human.
6. **Grades evidence separately from severity.** Every finding is P0/P1/P2 for impact and Verified/Flagged/Human-required for evidence basis, and takes the lower grade. A screenshot judgment call never masquerades as a machine-verified fact.
7. **Routes fixes to the party that can make them.** Theme findings name the likely file (`layout/theme.liquid`, the owning section or snippet) with concrete replacement values; app findings name the app and the route (settings vs vendor ticket).
8. **Files tracker tasks on request.** Reference flow is ClickUp via MCP (one task per grouped finding, priority-mapped, report attached as a doc); adaptable to any tracker.

Every finding follows one shape:

```
### [P1 · Verified] Link text fails contrast: SC 1.4.3
Observed: 14 instances across 3 pages; e.g. `.footer a` #767676 on #ffffff = 4.1:1 (needs 4.5:1).
Fix: darken to #595959 (7.0:1) or bump size to 24px/bold to qualify as large text.
Citation: WCAG 2.2 SC 1.4.3 (Contrast Minimum, Level AA). Engines: axe+lighthouse.
```

## Install

As a Claude Code plugin:

```
/plugin marketplace add kgelster/ecom-a11y-audit
/plugin install a11y-audit@kgelster-a11y
```

Or manually: clone this repo and copy `skills/a11y-audit/` into `~/.claude/skills/`.

Then ask for an audit ("run an accessibility audit on example-store.com").

## Requirements

- **Node.js with npx**: the scan script runs `npx --yes pa11y@9` and `npx --yes lighthouse@13` (first run downloads packages, ~1 min). No global installs required; `npm i -g pa11y lighthouse` skips the download wait.
- **Chrome/Chromium**: pa11y's Puppeteer downloads its own; Lighthouse uses your installed Chrome headless.
- **Python 3**: for `merge_findings.py` (stdlib only, no pip installs).

Works on password-protected dev stores (pa11y `actions` submit the password form) and unpublished themes (`?preview_theme_id=`). Non-Shopify sites scan fine too; the Shopify-specific steps are skipped and the report says so.

## What's inside

```
skills/a11y-audit/
├── SKILL.md                              the pipeline: scope → sample → scan → judge → report → tasks
├── scripts/scan.sh                       pa11y (axe + htmlcs, WCAG2AA) + optional Lighthouse per URL
├── scripts/merge_findings.py             normalize, dedup, compress, owner-tag; readability subcommand
├── scripts/focus_probe.js                in-page keyboard/focus probe for the interactive pass
├── references/manual-checks.md           the manual/model check catalog (what no engine covers)
└── references/shopify-attribution.md     app fingerprints, per-app failure families, fix routes
```

Design notes, for the curious:

- axe is run through pa11y rather than `@axe-core/cli` because the CLI's Selenium/ChromeDriver pairing breaks whenever Chrome updates ahead of ChromeDriver.
- axe is never run with only the `wcag22aa` tag: that tag selects only rules *new* to WCAG 2.2, which silently drops most of the ruleset.
- HTML_CodeSniffer warnings/notices are kept, not discarded: they're a pre-filtered queue of exactly the items worth human/model judgment (text-over-image contrast, unlabeled landmark candidates), at the cost of a high false-positive rate the model triages.
- Owner fingerprints are deterministic regexes over selector + markup, computed for every instance, not just the sampled nodes; unmatched instances are attributed by the model in the judge pass.
- The focus probe needs no OS window focus: Chrome won't apply `:focus` styles to a background tab, so when `document.hasFocus()` is false the probe switches from live focus() diffing to CSSOM analysis of the page's focus rules, and labels which method produced the result.
- Storefront sampling stays within a handful of page fetches: bot crawls of Shopify storefronts trip Cloudflare bans.
- The skill is an auditor, not a fixer. It recommends fixes with concrete replacement values (computed hex colors, aria-label patterns, the owning Liquid file) but does not edit code or write content without a separate ask.

## Contributing

PRs welcome. Every PR validates the skill's `SKILL.md` against the
[Agent Skills spec](https://agentskills.io/specification) via
`.github/scripts/validate_skills.py`. Run the same check before you commit with
`git config core.hooksPath .githooks`.

Behavioral changes should also pass the planted-fixture eval: `eval/run.sh` proves
the scanner pipeline still catches known defects (free, ~2 min), and `eval/run.sh
--e2e` grades a full model run of the skill before a release. See [eval/README.md](eval/README.md).

## License

MIT © Kurt Elster
