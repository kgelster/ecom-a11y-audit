# Shopify owner attribution: theme vs app

Every finding on a Shopify storefront has an owner, and the owner determines the fix route. Theme-owned issues are fixed in Liquid/CSS by whoever maintains the theme. App-injected issues cannot be fixed in theme code: the DOM belongs to the app, and the route is the app's own settings/custom-CSS field, or a support ticket to the vendor. Reports that ignore this send merchants to edit markup they don't control.

`merge_findings.py` pre-tags nodes with `owner` / `owner_hints` using the fingerprints below. Treat hints as strong but not final: confirm in the judge pass (an app widget rendered inside a theme section can carry both markers; app match wins because apps render inside sections). Instances with no hint need model attribution: look at the selector's ancestors, class prefixes, and which script owns the DOM subtree.

## Fingerprints (selector/markup markers)

- `rebuy` : Rebuy (cart drawer, upsells, bundles). Frequent offenders: `aria-hidden` drawer containing focusables, unlabeled bundle checkboxes, widget CTA contrast, carousel clone slides. Also the most common collision partner (see below): it replaces the theme's cart drawer without removing it.
- `okendo`, `oke-` : Okendo reviews. Star-filter rows as sub-24px `role="button"` divs, media-grid contrast over thumbnails.
- `klaviyo`, `kl-private` : Klaviyo forms/popups. Unlabeled email inputs, low-contrast placeholder-as-label, per-device visibility quirks.
- `jdgm` : Judge.me reviews. `loox` : Loox. `yotpo` : Yotpo. `stamped-` : Stamped. Review widgets share a failure family: star ratings conveyed by color/icon only, unlabeled filter controls, tiny tap targets.
- `privy`, `attentive`, `postscript` : popup/SMS capture. Focus not trapped in modal, no Escape close, close button unnamed.
- `recharge` : subscriptions. Radio/checkbox widgets with detached labels.
- `gorgias`, `tidio` : chat. Untitled iframes (`frame-tested` groups usually land here).
- `swym` : Swym wishlist. `smile-ui` : Smile.io loyalty launcher (fixed-position button, contrast + target size).
- `nosto`, `algolia`/`ais-`, `boost-pfs`/`boost-sd`, `snize` (Searchanise), `convermax` : search/merchandising. Facet checkboxes without labels, results announced without live regions.
- `shogun`, `pagefly`/`pf-`, `gempages`/`gp-` : page builders. Whole templates of divs-as-buttons and skipped headings; owner is the page built in the app, fix route is the builder's editor, not the theme.
- `afterpay`, `klarna`, `sezzle`, `paypal`/`zoid` : payment messaging/buttons. Untitled utility iframes; hidden, usually low priority, not actionable by the merchant.
- `arttrk` : ArtTrk ad pixel. 1x1 `<img>` without alt on every page; ask vendor for `alt=""` + `aria-hidden`, or accept as scan noise.
- `CybotCookiebot` (Cookiebot), `onetrust`/`optanon`, `consentmo`, `cookieyes`/`cky-`, `pandectes`/`pd-cp`, `shopify-pc__` (Shopify's native privacy banner) : consent management platforms. On nearly every store and on every page, so their findings inflate sitewide counts unless attributed. Failure family: banner text and button contrast, unnamed close/settings buttons, focus not moved into the dialog, banner covering content at 320px. Fix route: the CMP's admin settings (colors, labels, focus behavior) or a vendor ticket, never the theme; the theme does not render this DOM. Shopify's own banner: Settings > Customer privacy > Cookie banner.
- `samitaWS-` : Samita Wholesale. Replaces the storefront checkout button with injected DOM, so an unnamed or non-focusable checkout control (a P0) routes to the app, not the theme.
- `PBarNextFrame`, `preview-bar-iframe` : Shopify's preview bar, injected on every page scanned with `?preview_theme_id=`. A scan artifact, not a finding: the merge script drops it and reports the dropped count in `summary.md`. It never appears on the live theme.
- `shopify-section-*` and no app marker : theme-owned.

Apps not listed here: fingerprint from the page yourself (script `src` domains, class prefixes on the failing subtree) before attributing.

## Collisions: app and theme rendering the same UI

A third case the fingerprints can't express: an app takes over a piece of UI the theme also renders, and the two coexist. Neither component is broken by itself, so neither vendor owns the bug, and a report that blames one of them gets waved off.

The standing example is the cart drawer. A merchant installs an app cart (Rebuy Smart Cart is the usual one) on a theme that still ships its own drawer. Both listen for the cart toggle. The app drawer is what the user sees; the theme drawer opens too, translated offscreen, holding live tab stops. Keyboard users tab into a drawer they cannot see, and focus is stranded there when the app drawer closes. Symptoms in the probe output: `invisible_focusable` or `aria_hidden_focusable` clustered on cart markup, and a real-key check that loses focus after Escape.

Reporting shape: name it a collision, name both components, and route the half the merchant controls. The theme drawer is that half. The fix pattern that holds up: in the theme's cart-drawer snippet, set `inert` and `aria-hidden="true"` on the theme drawer whenever the app's cart container exists.

- The app container mounts **async**, after `load`. A one-shot check on DOMContentLoaded finds nothing and the guard silently does nothing. Watch `document.body` with a `MutationObserver` until the container appears, then disconnect.
- Make the guard self-disarm: if the app is later uninstalled and its container never appears, the theme drawer must go back to being the real cart.
- Never patch the *app's* DOM from theme JS to fix the app's own half; it breaks on the next app release.

Other collisions worth checking when both are installed: two review widgets on one PDP (duplicate star ratings, two sets of filter controls), an app search overlay over the theme's own predictive search, and a popup app plus a theme newsletter modal (two focus traps racing for the same first-visit moment).

## Fix routes by owner

- **theme** : Liquid/CSS edit in the theme repo or theme editor. Follow the patterns in Shopify's `liquid-theme-a11y` skill (AI toolkit plugin) if installed. Name the file when you can infer it (`layout/theme.liquid` for viewport meta, the section/snippet rendering the failing selector otherwise).
  - **Adding `alt` to a bare `<img>`: do not add `width`/`height` in the same edit unless the CSS already sets `height: auto`.** The HTML `height` attribute is a presentational hint (`height: 1791px`), and a stylesheet that only sets `width` does not override it. Result: a 600px-wide render stretched to the intrinsic pixel height, shipped as an a11y fix. Seen live on hoonigan.com 2026-09-04 (Garage Squad hero badge, `#floatimg`, CSS `width: 80%; max-width: 600px` and no height). If you add the attributes for CLS, add `height: auto` to the same selector and check the rendered box (`getBoundingClientRect()` against the natural aspect ratio) before pushing. The fix that only touches `alt` cannot regress layout; prefer it.
- **app with a settings/CSS surface** (Rebuy, Okendo, Klaviyo, review apps): route to the widget's own settings or custom-CSS field first; escalate to vendor support with the selector + WCAG SC when settings can't reach the markup (e.g. Rebuy's aria-hidden carousel clones are their markup, not configurable).
- **what escalation actually gets you.** Expect the vendor to decline any compliance claim (no app vendor certifies a merchant as ADA/WCAG conformant) while still being willing to ship a per-merchant workaround through the widget's lifecycle hooks: Rebuy's SmartCart exposes ready/show/hide JS callbacks, most popup and review apps expose a custom-JS or custom-CSS field. Three traps when a workaround lands there:
  - A lifecycle callback is usually **one function**. Inherited dead code above your fix kills it: a widget copied from an older setup carries `addEventListener` wiring for theme selectors that no longer exist, the `null` throws, and everything below never runs. Null-guard the inherited lines instead of deleting them blind.
  - Those editors are often Monaco embedded in a Vue admin, where pasted text via automation does not register. Set the value through the editor's own API (`monaco.editor.getModels()[i].setValue(...)` from the page console) so the app sees the change and enables Save.
  - App config saves propagate through the vendor's CDN on their schedule, minutes not seconds. Verify the fix on the storefront, never in the admin preview, and re-verify after the cache window. If the vendor staged the change on a *copy* of the widget, confirm which copy is live before you call it shipped.
- **consent banner (CMP)** : the CMP's admin settings first (Cookiebot, OneTrust, Consentmo, CookieYes, Pandectes all expose colors and labels), vendor ticket for dialog semantics and focus handling. Shopify's native banner is configured under Settings > Customer privacy. Theme CSS overrides of banner DOM break on the CMP's next release.
- **app with no surface** (pixels, payment iframes, chat launchers): vendor ticket or accept-and-document. Never tell the merchant to patch app DOM from theme JS; it breaks on every app update.
- **merchant content: product and theme image alt** : usually the largest instance count in a report, and it does not need per-product admin edits or a `write_products` scope. Product images are `MediaImage` files, so `fileUpdate(files: [{id, alt}])` with `write_files` sets alt in batches. Build the worklist by pairing the public `/products.json` (image URLs and positions) with `files(query: "media_type:IMAGE")` matched on filename; theme images resolve from the `shopify://shop_images/...` references in templates and `settings_data.json`. A whole catalogue is an hour's job this way. The alt values themselves still need the owner's sign-off (see Failure modes in SKILL.md).
- **checkout** : Shopify-hosted and locked on non-Plus plans; report as out of scope/Undetermined, not as passed. Plus stores using checkout extensibility own their customizations only.

## Report shape

App-injected findings get their own report section grouped by app, each with: the finding, instance count, and the route (settings vs support ticket). This is the section a merchant forwards verbatim to each vendor.
