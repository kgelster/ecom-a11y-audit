# Manual / model check catalog

Re-read this file at step 4 of every audit, including repeat audits in the same session, so checks don't silently drop out. Every check below ends the run in exactly one state: Verified finding, Flagged finding, Pass (only if actually exercised), or **Not exercised** (free and honest; never report as pass).

## Per-check instructions

### Alt text quality (SC 1.1.1): always run
Scanners only check presence. For each sampled page, list images with their alt attributes and flag:
- Filename alts: `alt="IMG_2041.jpg"`, `alt="hero-banner-final-v2"`
- Filler: `alt="image"`, `alt="photo"`, `alt="logo"` (logo alt should name the company)
- Redundant: alt duplicating the adjacent heading/caption verbatim
- Meaningful image with `alt=""` (product photos, infographics, charts)
- Decorative image *with* alt (dividers, spacers, ambient backgrounds)
- Product images: alt should identify the product, ideally variant ("blue variant, side view"), not marketing copy
Grade: Flagged (quality is a judgment call). Evidence: one selector + the current alt per pattern, then stop.

### Link and button accessible names (SC 2.4.4, 4.1.2): always run
Engines catch *empty* names. You catch *useless* ones:
- "Click here", "Read more", "Learn more" repeated with different targets (SC 2.4.4; Lighthouse `identical-links-same-purpose` sometimes catches it)
- Icon-only buttons whose aria-label doesn't match the action ("button" as a label)
- Links whose accessible name differs wildly from visible text (SC 2.5.3 Label in Name)

### Contrast (SC 1.4.3, 1.4.11): re-probe the settled state, always
Two separate jobs, and the first one is not optional on a Shopify theme.

**Settled-state re-probe.** axe measures at load, which on an animated theme means mid-fade. Inject `scripts/contrast_reprobe.js` (SKILL.md step 4d) before reporting any contrast number: it forces entrance animations to their end state and recomputes ratios from composited colors. `at_risk: true` means the scanner's count is unusable as printed. Only `fail` rows may be reported as failures, and the report says both counts. A theme audited this way reported 318 axe contrast failures and zero real ones.

**Indeterminates.** Text over images/gradients/CSS variables the engine punted on, plus anything the probe returns as `indeterminate`: a CSS background image in the chain, an `<img>` painted behind a text overlay (hero and collection cards), unresolved color syntax, computed `rgba(0,0,0,0)` knockout type. With a screenshot: judge worst-case region, report Flagged with screenshot. Without: report as indeterminate with selector. Never estimate a numeric ratio you didn't compute from actual colors.

**Non-text contrast (1.4.11)**: focus indicators, form field borders, icon buttons against 3:1.

### Keyboard access (SC 2.1.1, 2.1.2, 2.4.7): run the interactive pass (SKILL.md step 4f)
Agent-driven: inject `scripts/focus_probe.js` for the deterministic layer (tab stops, aria-hidden focusables, invisible tab stops, positive tabindex, skip link, focus-indicator heuristic), then real-key spot checks for what a probe cannot prove:
- Every interactive element reachable and operable (Enter/Space)
- Focus visible on each stop (invisible focus ring = P1 Flagged; confirm with real Tab, the probe's heuristic has both false positives and negatives)
- No traps (can't tab out of a widget = P0)
- Modals/drawers: focus moves in on open, returns on close, Escape closes
- Two drawers answering one toggle (an app cart installed over the theme's own): focus lands in the invisible one. See `shopify-attribution.md`, Collisions.
- Skip link present and functional on first Tab
Without any browser driver: Not exercised. The list above doubles as the checklist for a human tester.

### Reflow and zoom (SC 1.4.4, 1.4.10): run the interactive pass (SKILL.md step 4f)
Resize the driven window to 320px width: re-inject the probe (`horizontal_overflow`), screenshot for clipped/overlapping content. Zoom to 200%: text scales, nothing lost. Check `meta-viewport` doesn't set `user-scalable=no` or `maximum-scale=1` (scanners catch this one). Without a driver: Not exercised.

### Target size (SC 2.5.8): engine-owned, verify samples
axe/Lighthouse `target-size` covers it (24×24 CSS px minimum with spacing exceptions). If flagged, screenshot one instance to confirm it's not an inline-text exception before reporting P1.

### Color-only meaning (SC 1.4.1): always run when screenshots available
Links inside body text distinguishable only by color (Lighthouse `link-in-text-block` partial); status conveyed only by dot color; required fields marked only by red. The "no programmatic equivalent" half may be Verified from the DOM; the "color is the sole carrier" half is interpretive, so the finding is Flagged.

### Reading order / visual order (SC 1.3.2): Flagged at best
All 13 tools in the GDS accessibility-tool audit missed this. Compare DOM order (source) with visual layout on screenshot. CSS `order`/`flex-direction: row-reverse`/absolute positioning are the smells.

### Forms (SC 3.3.1, 3.3.2, 1.3.5): when forms sampled
Beyond label presence (engine-owned): error messages identify the field and say how to fix; errors announced (aria-live or focus moved); `autocomplete` attributes on identity fields (1.3.5); required indication not color-only; labels visible (placeholder-as-label = Flagged P1).

### Semantic HTML (SC 1.3.1): always run, cheap
From page source: one `<h1>`; heading levels don't skip; `<main>`/`<nav>`/`<footer>` landmarks present; lists are `<ul>/<ol>` not styled `<div>`s; data tables have `<th>`; clickable `<div>`s that should be `<button>` (also 2.1.1: they're usually not keyboard-operable).

### Motion and timing (SC 2.2.1, 2.2.2, 2.3.1): always include
Cannot be automated at all: carousels auto-advance with no pause control; session timeouts without warning; autoplaying video/animation without pause; flashing content. Check what you can from source (autoplay attributes, carousel libs), mark the rest Human-required.

### Readability (SC 3.1.5, AAA: advisory only)
`merge_findings.py readability <textfile>`. Report grade level as a recommendation. Do not count in violation totals.

## High-risk patterns: name the contract, verify what you can, hand off the rest
Custom comboboxes/autocompletes, carousels, drag-and-drop, rich text editors, data grids, tree views, live-region-heavy UI (cart drawers, toasts). For each present on a sampled page: name the APG pattern it should implement, state the keyboard/ARIA contract it owes, check the cheap DOM half (roles, aria-expanded, tabindex), and put the behavioral half on the Human-required list with the specific question a tester should answer.

## Known engine blind spots (for the coverage disclosure)
No scanning engine checks: alt text quality, reading order, focus-indicator visibility quality, context-dependent color use, caption/transcript quality, error-message usefulness, cognitive load, motion/timing behavior. Of these, keyboard operability, focus visibility, and reading-order smells are covered by the interactive pass when a browser driver is present (probe + real keys); the rest, and everything a screen reader announces, stays with a human. State this split in every report.
