#!/usr/bin/env bash
# a11y-audit scanner: runs pa11y (axe + htmlcs engines) and optionally Lighthouse
# against each URL, writing raw JSON into an output directory.
#
# Usage:
#   scan.sh OUTDIR URL [URL...]
#   LIGHTHOUSE=1 scan.sh OUTDIR URL [URL...]   # also capture Lighthouse a11y category
#
# Output files per URL (N = 1-based index, slug = sanitized URL):
#   OUTDIR/pa11y-N-<slug>.json      pa11y issues (axe + htmlcs, WCAG2AA)
#   OUTDIR/lh-N-<slug>.json         Lighthouse accessibility category (if LIGHTHOUSE=1)
#   OUTDIR/urls.tsv                 index of N <TAB> URL
#   OUTDIR/redirects.tsv            N <TAB> requested URL <TAB> final URL after redirects
#
# Notes:
# - pa11y exits 2 when issues are found; that is success for our purposes.
# - Preflight: pa11y is launched once against a local file before the URL loop
#   and the run aborts (exit 3) if Chrome fails to start. pa11y's Puppeteer
#   Chrome and Lighthouse's system Chrome are different binaries: with the
#   Puppeteer one broken (corrupted ~/.cache/puppeteer from an interrupted
#   download) every pa11y JSON comes back empty while Lighthouse returns full
#   results, a partial scan that looks complete. PREFLIGHT=0 skips the check.
# - Each URL is resolved with curl first; a redirect is logged to redirects.tsv
#   and warned about, and a destination already in the scan is flagged as a
#   duplicate (an empty /cart 301ing to / scans the homepage twice).
# - Uses npx --yes with pinned majors (pa11y@9, lighthouse@13) so a scanner major
#   bump can't silently change results; first run downloads packages (~1 min).
set -uo pipefail

OUTDIR="$1"; shift
mkdir -p "$OUTDIR"
: > "$OUTDIR/urls.tsv"
: > "$OUTDIR/redirects.tsv"

if [ "${PREFLIGHT:-1}" = "1" ]; then
  pf="$OUTDIR/preflight.html"
  printf '<!doctype html><html lang="en"><head><title>preflight</title></head><body><main><h1>preflight</h1></main></body></html>' > "$pf"
  echo "[preflight] pa11y Chrome launch check" >&2
  pf_out=$(npx --yes pa11y@9 "$pf" --runner axe --reporter json 2>> "$OUTDIR/scan-errors.log")
  pf_rc=$?
  rm -f "$pf"
  case "$pf_out" in
    \[*) ;;
    *)
      echo "PREFLIGHT FAILED: pa11y could not launch its Chrome (exit $pf_rc, see $OUTDIR/scan-errors.log)." >&2
      echo "Aborting before the URL loop: continuing would produce empty pa11y files next to full Lighthouse results." >&2
      echo "Recovery: rm -rf ~/.cache/puppeteer ~/.npm/_npx  then re-run (a fresh npx install re-downloads Chrome)." >&2
      echo "  If npx-cached pa11y keeps failing with 'could not resolve executablePath', install the build" >&2
      echo "  its puppeteer expects: npx --yes @puppeteer/browsers install chrome@<build> --path ~/.cache/puppeteer" >&2
      exit 3 ;;
  esac
fi

i=0
for url in "$@"; do
  # only http(s) URLs: anything else (including dash-prefixed strings, e.g. from a
  # hostile sitemap) would be parsed as a CLI flag by pa11y/lighthouse
  case "$url" in
    http://*|https://*) ;;
    *) echo "SKIP non-http(s) argument: $url" >&2; continue ;;
  esac
  i=$((i+1))
  slug=$(echo "$url" | sed -E 's~https?://~~; s~[^A-Za-z0-9]+~-~g; s~-+$~~' | cut -c1-60)
  printf '%s\t%s\n' "$i" "$url" >> "$OUTDIR/urls.tsv"

  final=$(curl -sL -o /dev/null --max-time 30 -A "Mozilla/5.0 (a11y-audit scan)" -w '%{url_effective}' "$url" 2>/dev/null || true)
  [ -n "$final" ] || final="$url"
  printf '%s\t%s\t%s\n' "$i" "$url" "$final" >> "$OUTDIR/redirects.tsv"
  # Shopify answers ?preview_theme_id= with a cookie-setting 302 back to the bare
  # URL. Cookie-less curl lands on the bare URL, but pa11y/Lighthouse keep the
  # cookie and measure the preview theme, so that hop is not a redirect the scan
  # measures. Compare with the parameter stripped from both sides.
  strip_preview() { printf '%s' "$1" | sed -E 's/([?&])preview_theme_id=[0-9]+&?/\1/; s/[?&]$//'; }
  url_cmp=$(strip_preview "$url"); final_cmp=$(strip_preview "$final")
  if [ "${final_cmp%/}" != "${url_cmp%/}" ]; then
    echo "  WARN redirect: $url -> $final (the scan measures the destination)" >&2
    dup=0
    for other in "$@"; do
      [ "$other" != "$url" ] && [ "${other%/}" = "${final%/}" ] && dup=1
    done
    if [ "$dup" = "1" ]; then
      echo "  WARN duplicate: $final is already in this scan. An empty /cart often 301s to /; add an item first (scan /cart/add?id=<variant_id>) or drop the page." >&2
    fi
  fi

  echo "[$i] pa11y (axe+htmlcs): $url" >&2
  npx --yes pa11y@9 "$url" \
    --runner axe --runner htmlcs \
    --standard WCAG2AA \
    --include-warnings --include-notices \
    --timeout 60000 \
    --reporter json > "$OUTDIR/pa11y-$i-$slug.json" 2>> "$OUTDIR/scan-errors.log"
  rc=$?
  if [ $rc -ne 0 ] && [ $rc -ne 2 ]; then
    echo "  WARN pa11y exit $rc for $url (see scan-errors.log)" >&2
  fi

  if [ "${LIGHTHOUSE:-0}" = "1" ]; then
    echo "[$i] lighthouse: $url" >&2
    npx --yes lighthouse@13 "$url" \
      --only-categories=accessibility \
      --output=json --output-path="$OUTDIR/lh-$i-$slug.json" \
      --chrome-flags="--headless=new" --quiet 2>> "$OUTDIR/scan-errors.log" \
      || echo "  WARN lighthouse failed for $url" >&2
  fi
done

echo "Scan complete: $OUTDIR" >&2
