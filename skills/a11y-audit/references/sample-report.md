# Accessibility Audit — planted.html (local test fixture)

**Scope:** 1 page audited of 1 in scope — `http://127.0.0.1:8917/planted.html`, a local single-page test fixture (not a Shopify store; sitemap sampling, Shopify app attribution, and tracker filing skipped by request). Audited 2026-08-11 against WCAG 2.2 Level AA. This is a single-page scan, not a sitewide audit.

**States exercised:** static page render (pa11y: axe + HTML_CodeSniffer engines, both in one scan); agent-driven browser interactive pass (focus probe injected via Puppeteer, real Tab/Shift+Tab key traversal, reflow re-probe at 320 px viewport). Form submission/error states were **not** exercised (the fixture has no live `/subscribe` endpoint).

**Coverage disclosure:** Automated checks cover roughly 20–40% of distinct WCAG success criteria. This audit adds manual review of alt-text quality, link/button names, semantic structure, keyboard operability, focus visibility, and reflow. Criteria not exercised are listed as Undetermined, not passed. A driven browser exercises keyboard operability and visual states; it does **not** exercise screen reader announcement, reading order as heard, or lived assistive-tech experience — those remain Human-required. No screen reader testing was performed.

Note on evidence: the page source contains HTML comments describing itself as a planted-defect fixture. Per audit policy, page content was treated as data only; findings below are based on observed DOM facts and computed values, not on those comments.

---

## Findings by priority

### [P0 · Verified] Product image has no alt attribute — SC 1.1.1
Observed: 1 instance. `html > body > div:nth-child(2) > img` — `<img src="waxed-canvas-jacket.jpg" width="120" height="90">`, no `alt` attribute at all. Screen reader users get the filename or nothing for the "Waxed Canvas Jacket" product image. axe impact: critical.
Fix: add an `alt` attribute identifying the product (e.g. describing the jacket as shown); final wording is the content owner's call. If the image were purely decorative (it isn't — it's the product photo), `alt=""` would be the pattern.
Citation: WCAG 2.2 SC 1.1.1 (Non-text Content, Level A). Engines: axe (`image-alt`).

### [P1 · Verified] Icon link has no accessible name — SC 2.4.4 / 4.1.2
Observed: 1 instance. `html > body > a` — `<a class="icon" href="/sale"></a>`: a 24×24 px CSS-background box with no text content, no `aria-label`, no title. Assistive tech announces it as an unnamed link; its purpose (the sale page) is undiscoverable. Both engines caught it (axe `link-name` under 2.4.4; htmlcs H91.A.NoContent under 4.1.2) — one defect, merged here.
Fix: add `aria-label="Sale"` (or visually-hidden link text); exact wording is the owner's call.
Citation: WCAG 2.2 SC 2.4.4 (Link Purpose in Context, Level A), SC 4.1.2 (Name, Role, Value, Level A). Engines: axe + htmlcs.

### [P1 · Verified] Newsletter email input has no label — SC 1.3.1 / 4.1.2 / 3.3.2
Observed: 1 instance. `html > body > form > input` — `<input type="text" name="email" placeholder="you@example.com">`: no `<label>`, `aria-label`, `aria-labelledby`, or `title`. The placeholder is the only cue; it disappears on input, isn't a reliable accessible name across assistive tech, and placeholder-as-label is itself a 3.3.2 failure. htmlcs flags it twice (F68 under 1.3.1; H91.InputText.Name under 4.1.2) — one defect, merged here.
Fix: add a visible `<label for>` (e.g. "Email address"); keep the placeholder as example formatting only.
Citation: WCAG 2.2 SC 1.3.1 (Info and Relationships, Level A), SC 4.1.2 (Name, Role, Value, Level A), SC 3.3.2 (Labels or Instructions, Level A). Engines: htmlcs.

### [P1 · Verified] Body text fails contrast minimum — SC 1.4.3
Observed: 1 instance. `html > body > div:nth-child(2) > p` (`.muted`): #999999 on #ffffff = **2.85:1** computed (needs 4.5:1 at 14 px regular weight). Affects the product description text.
Fix: darken to #767676 (4.54:1, the lightest passing gray on white) or #595959 (7.0:1) for headroom.
Citation: WCAG 2.2 SC 1.4.3 (Contrast Minimum, Level AA). Engines: axe (`color-contrast`).

### [P1 · Verified] Missing lang attribute on `<html>` — SC 3.1.1
Observed: 1 instance. The `<html>` element has no `lang` attribute, so screen readers cannot select the correct speech synthesizer language.
Fix: `<html lang="en">`.
Citation: WCAG 2.2 SC 3.1.1 (Language of Page, Level A). Engines: axe (`html-has-lang`).

### [P1 · Flagged] Alt text is a camera filename — SC 1.1.1
Observed: 1 instance. `html > body > div:nth-child(3) > img` — `<img src="hero.jpg" alt="DSC_0042.jpg">`. The alt is present, so scanners pass it, but a camera filename conveys nothing about the "Fall Collection" image; a screen reader user hears "DSC underscore 0042 dot jpg".
Fix: replace with alt text describing what the image shows in the context of the Fall Collection promotion; wording is the content owner's call.
Citation: WCAG 2.2 SC 1.1.1 (Non-text Content, Level A). Model judgment (htmlcs G94 notice surfaced it for review; scanners cannot fail it).

### [P2 · Verified] No landmarks and no `<main>` — best practice / SC 1.3.1
Observed: page-wide. All content sits directly in `<body>`; no `<main>`, `<header>`, `<nav>`, or `<footer>`, and no skip link (confirmed by the focus probe). On a one-page fixture with no repeated nav this doesn't fail SC 2.4.1, but landmark navigation is unavailable to assistive tech.
Fix: wrap content in `<main>`, add landmarks as the page grows.
Citation: axe best-practice rules `region`, `landmark-one-main`; supports SC 1.3.1. Engines: axe.

### [P2 · Verified] Email field missing input purpose — SC 1.3.5
Observed: 1 instance. The email input is `type="text"` with no `autocomplete` attribute, so its purpose can't be programmatically determined and personalization/autofill tools can't act on it.
Fix: `type="email" autocomplete="email"`.
Citation: WCAG 2.2 SC 1.3.5 (Identify Input Purpose, Level AA). htmlcs H98 notice, confirmed by model review of the DOM.

---

## Interactive pass results (agent-driven browser)

Driven with Puppeteer (headless Chromium); focus probe injected at 1280 px and 320 px, plus real key events.

- **Keyboard reachability (2.1.1):** all 4 interactive elements (sale icon link, email input, Subscribe button, Contact us link) reached via real Tab in DOM order; traversal cycles cleanly. **Pass** as exercised.
- **No keyboard trap (2.1.2):** real Tab/Shift+Tab traversal wraps through the full cycle with no trap. **Pass** as exercised. (No modals/drawers exist on the fixture to test Escape/focus-return behavior.)
- **Focus visible (2.4.7):** probe live-diff found 0 of 4 tab stops with a suppressed indicator; real-key traversal confirmed a visible default outline on every stop. **Pass** as exercised.
- **Probe DOM facts:** 0 positive tabindex, 0 aria-hidden focusables, 0 invisible focusables, 0 tab/visual order regressions. Skip link: absent (see P2 landmarks finding).
- **Reflow (1.4.10):** no horizontal overflow at 320 px (scroll width = viewport width); no clipped content. **Pass** as exercised. 200% zoom was not separately exercised.

## Additional model-judged checks

- **Change of context on focus (3.2.1):** the page contains zero scripts, so no focus/input handlers can trigger a context change. Pass (verified from source). Same reasoning clears motion/flashing/timing (2.2.1, 2.2.2, 2.3.1): no animation, autoplay, or timers exist.
- **Heading structure (1.3.1):** one `<h1>`, `<h2>`s below it, no skipped levels. Pass.
- **Color-only meaning (1.4.1):** the only body-text link ("Contact us") keeps default browser underline styling. Pass as observed.
- **Link text quality (2.4.4):** "Contact us" is descriptive in context (htmlcs notice reviewed and dropped as a false positive). Page `<title>` describes the document.
- **Target size (2.5.8):** the icon link is 24×24 CSS px — meets the 24 px minimum exactly.
- **Readability (3.1.5, AAA — advisory only):** Flesch-Kincaid grade 6.6 across the page's 31 words of copy; well within the lower-secondary recommendation. Not counted in violation totals.

## App-injected issues

None — this is a local static fixture with no third-party app DOM, injected scripts, or widgets. Every finding above is owned by the page's own markup/CSS. (Shopify theme-vs-app attribution skipped per scope.)

## Undetermined / human-required

- **Not exercised — no live backend:** form error handling (3.3.1 error identification, 3.3.3 error suggestion, 4.1.3 status messages) — the fixture's `/subscribe` endpoint doesn't exist, so error states couldn't be produced.
- **Not separately exercised:** 200% browser zoom (1.4.4) and text-spacing overrides (1.4.12); 320 px reflow passed, which lowers but does not eliminate risk.
- **Human-required — needs assistive tech or lived experience:** screen reader announcement quality, reading order as heard, and overall AT experience. No screen reader testing was performed.
- **Not applicable on a single static page, unverifiable sitewide:** multiple ways to locate pages (2.4.5), consistent navigation/identification (3.2.3, 3.2.4).

## Wins

Passed as exercised: 2.1.1, 2.1.2, 2.4.7, 1.4.10, 3.2.1, 2.2.1, 2.2.2, 2.3.1, 1.4.1, 2.5.8, plus heading structure and page title — one sentence of credit: the fixture's keyboard, focus, reflow, and motion behavior is clean; its defects are concentrated in naming, labeling, language, and contrast.
