# Shinylive Browser Tests

These tests require an existing Shinylive export at `site/index.html`. They never
launch R, export the app, or substitute a mocked UI. The Node server mounts only
`site/` at `http://127.0.0.1:4173/projections-app/`, serves WASM as
`application/wasm`, and adds no COOP/COEP isolation headers.

## Run

```sh
npm ci
npx playwright install chromium webkit
npm run test:browser
```

Use `npm run test:browser:desktop` or `npm run test:browser:mobile` for a subset.
`npx playwright test --list` validates test discovery without requiring an export.
The suite uses Chromium for both desktop and Pixel 7 emulation, not a physical
Android device, plus a separate WebKit regression test. There are twelve tests,
one worker, no retries, and readiness
polling with a 120-second cold-start limit. Each workflow has a fresh browser.

Run `npm run test:browser:webkit` for the Safari regression. If a local preview
is already running, use `PLAYWRIGHT_REUSE_SERVER=1 npm run test:browser` to reuse
it; CI always starts its own server. GitHub Actions runs Chromium on Linux and
WebKit on macOS against the same exported artifact.

## Coverage

- Example projection values, rounding, and unrounded CSV precision.
- Singular projected year and multi-year range labels.
- Constant, manual, and uploaded entry enrollment; cohort propagation.
- CSV and XLSX historical, separate base, and out-of-order entry uploads.
- Case-insensitive headers and first-worksheet-only XLSX handling.
- Invalid horizon, grade order, manual counts, entry years, missing history,
  blank historical counts, and mismatched base year clear tables, plot, summary,
  and ratios; corrected inputs restore results.
- Contents and filenames of all five downloads.
- Rejected download fetch shows an accessible alert; the next click completes a
  real download with correct contents and clears the alert.
- Total and grade plot images load, have alt text, and change on grade selection.
- Mobile sidebar, all three steps, manual input, plot, responsive HTML caption,
  and horizontal overflow.
- WebKit startup, example projections, manual entry changes, Excel entry upload,
  projection download contents, loaded chart images, and narrow-screen resizing.

Fixtures are synthetic and generated in memory. XLSX is a small OOXML archive
created with `fflate`; neither ExcelJS nor an R fixture-generation script is used.
Legacy binary `.xls` is not covered.

## Diagnostics And Privacy

Artifacts are under `tests/browser/artifacts/`: HTML report, success and failure
screenshots, failure traces, console/page errors, failed requests, network audits, and
Chromium NetLog. Run `npm run test:browser:report` to inspect the HTML report.
`node_modules/` and generated browser artifacts are excluded by `.gitignore`.

For Chromium, before any page starts, `browserContext.route` aborts requests outside the local
test origin. Any attempted external request fails the audit even if blocked.
Service workers remain enabled for Shinylive; because routing is not a complete
worker/network boundary, browser-wide NetLog independently checks all observed
external traffic, external writes, school-name sentinel leaks, and HTTP errors.
There is no external allowlist. Report any unexpected runtime dependency rather
than waiving these checks.

Each test retains one raw `chromium-netlog.json` and a small `network-audit.json`.
The raw log is copied into the HTML report only on failure, avoiding duplicate
large success artifacts. Default NetLog avoids raw socket payload capture; this
is an observed-traffic regression check, not a complete exfiltration sandbox.
The failure-feedback test mocks only one matching iframe `fetch` rejection and
restores the original function before retrying. All successful downloads use the
real application, service worker, Blob delivery, and Playwright download event.

## Export Verification: 2026-09-06

`npm run test:browser` completed in **2.8 minutes: 11 passed, 0 failed**, without
skips or retries. Tested the supplied Shinylive 0.5.0 / assets 0.10.12 export with
webR R 4.6.0 using Playwright 1.63.0 / Chromium 153.0.8010.12.

All coverage listed above passed, including real filenames and full CSV contents
for all five downloads. The mobile sidebar is intentionally stacked below
the main content in this non-fillable bslib layout, not collapsible. Exact bslib
attachment messages are retained in diagnostics but excluded from console errors:
Shinylive's `terminalInterface` forwards all R stderr to `console.error`.

### Resolved Findings

The refreshed app's browser-local download bridge resolves the previous virtual
download-route failures. Real browser download assertions are unchanged; stale
diagnostic re-fetches and per-download debug JSON have been removed.

Moving the chart caption to responsive HTML resolves mobile caption clipping.
The mobile test checks that the complete caption is visible and fits horizontally.
Screenshot inspection confirms the caption wraps and chart year ticks are integers.

### Network Findings

All eleven tests in the final headless-shell run have empty `blockedExternal`,
`external`, and `httpErrors` arrays in their `network-audit.json`. No external
enrollment requests, runtime asset requests, or missing assets were observed,
including browser-level worker traffic.
The static Node server still adds no custom isolation headers. Shinylive's service
worker independently adds COEP/CORP to its synthetic responses; the app iframe
remains `crossOriginIsolated === false`.

### Screenshots

Screenshots under `artifacts/results/`:

- `projections-example-number-4691f-entry-and-total-grade-plots-desktop/desktop-total-plot.png`
- `projections-example-number-4691f-entry-and-total-grade-plots-desktop/desktop-grade-chart.png`
- `projections-example-number-4691f-entry-and-total-grade-plots-desktop/desktop-grade-plot.png` (page)
- `mobile-mobile-sidebar-step-250c2--and-plot-table-stay-usable-mobile/mobile-chart.png`
- `mobile-mobile-sidebar-step-250c2--and-plot-table-stay-usable-mobile/mobile-chart-caption.png`
- `mobile-mobile-sidebar-step-250c2--and-plot-table-stay-usable-mobile/mobile-results.png` (page)

The export uses a scrolling iframe, so outer-page full-page screenshots do not
capture its entire scrollable content; dedicated chart screenshots are included.

### Remaining Manual Checks

- Real GitHub Pages deployment, including fresh and previously cached service
  workers, should be smoke-tested after publishing.
- Real mobile devices, branded Safari, Firefox, and headed-browser download UX
  remain outside the automated Chromium and Playwright WebKit suite.
- Binary `.xls` and screen-reader behavior are not covered.
- Integer ticks and visual plot fidelity were inspected in screenshots, not
  asserted using OCR or image baselines.
- Download failures from HTTP errors or malformed response headers are not
  separately injected; the recovery test covers a rejected fetch promise.

## Safari Regression

The original export failed in macOS WebKit with `Maximum call stack size
exceeded` while rendering the initial UI. Pre-rendering the static UI fixed
startup, but `renderPlot()` then overflowed while evaluating chart inputs.
Rendering the same ggplot through `renderImage()` avoids that deeper stack.
The WebKit regression must produce a loaded chart, not merely a visible page.
It also covers dynamic inputs, an Excel entry file, a real CSV download, and
resizing; detached frames during the service-worker startup reload are retried.

WebKit captures console and uncaught-page-error diagnostics but does not use
Chromium NetLog. Its uncaught-error assertions apply to the active document;
messages from service-worker activation and the resulting navigation are retained
in diagnostics. Do not treat this test as a worker-wide network privacy audit.
