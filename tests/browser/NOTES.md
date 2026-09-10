# Shinylive Browser Tests

These tests require an existing Shinylive export at `site/index.html`. They never
launch R, export the app, or substitute a mocked UI. The Node server mounts only
`site/` at `http://127.0.0.1:4173/projections-app/`, serves WASM as
`application/wasm`, and adds no COOP/COEP isolation headers.

The suite tests the one-page form/results layout, including the reduced-click
path from historical upload to projection download.

## Run

```sh
npm ci
npx playwright install chromium webkit
npm run test:browser
```

Use `npm run test:browser:desktop` or `npm run test:browser:mobile` for a subset.
`npx playwright test --list` validates test discovery without requiring an export.
The suite uses Chromium for both desktop and Pixel 7 emulation, not a physical
Android device, plus a separate WebKit regression test. There are fourteen tests,
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
- Manual values survive projection-period changes and an invalid base-year edit.
- CSV and XLSX historical, separate base, and out-of-order entry uploads.
- Case-insensitive headers and first-worksheet-only XLSX handling.
- Invalid horizon, grade order, manual counts, entry years, missing history,
  blank historical counts, and mismatched base year hide the entire projection
  body, including tables, plot, summary and download; corrected inputs restore
  results. Hidden stale DOM is allowed; visibility, not zero row counts, is tested.
- Contents and filenames of all five downloads.
- Rejected download fetch shows an accessible alert; the next click completes a
  real download with correct contents and clears the alert.
- Total and grade plot images load, have alt text, and change on grade selection.
- No tabs or sidebar; a single Project enrollment h1, continuous inputs before
  results in DOM order, side-by-side sections at 1280px and stacked at 430px.
- Example chart and download visible without navigation; CSV/XLSX history upload
  automatically selects uploaded data without first changing the source radio.
- Uploaded common grade labels are suggested lowest-to-highest without changing
  their spelling. The field remains editable; uncertain labels retain file order
  and display a review warning rather than receiving an arbitrary order.
- Visible inline source choices, unchanged entry labels, visible grades/horizon,
  native grade/method selects, and a definition-list projection summary.
- Native disclosures with exact summary labels for advanced settings, history
  preview, projection table and ratios. `disclosure()` opens only closed details;
  there is no tab helper. Startup waits for visible `#history_status` with
  `9 records`, never a table inside a closed disclosure.
- History template outside disclosures, entry template conditional on upload,
  prominent projection download, and accessible success/error status.
- Mobile keyboard activation of skip/results links and an advanced-settings
  summary, all inputs before results, manual input, loaded plot, responsive HTML
  caption and no document-level horizontal overflow, including a 320px viewport.
- WebKit startup, example projections, manual entry changes, Excel entry upload,
  projection download contents, loaded chart images, invalid-edit recovery,
  automatic history-source selection and narrow-screen resizing.

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

## One-Page Export Verification

The final run of `PLAYWRIGHT_REUSE_SERVER=1 npm run test:browser` passed all
**14 tests in 4.3 minutes**, without skips or retries. All numerical and CSV
expectations remain unchanged.

Two issues found during the redesign now have regression coverage. Existing
manual-entry input nodes are retained when the horizon changes, so a delayed
form redraw cannot discard edits. High-priority observers resolve settings and
projections before outputs render, preventing a Safari stack overflow when
historical data changes while results are visible.

### Layout And Diagnostics

- Visually inspected complete 1280px desktop and 430px mobile layouts: desktop
  inputs/results are side by side, desktop source radios remain on one line,
  mobile inputs precede stacked results, and the chart/caption/footer are not
  clipped. Source choices stack at 430px. No desktop radio-wrap defect observed.
- Mobile skip link and the header `.service-header a[href="#results"]` work with
  keyboard activation. The second View projection link remains in the form.
  Native disclosure keyboard activation passes. The 320px sample chart loads
  and document-width assertions pass.
- Full-layout screenshots temporarily expand only viewport height, retaining
  the tested width, then restore the original viewport. This avoids iframe
  clipping that persisted even with a plain iframe-body screenshot.
- All 13 Chromium network audits pass: no attempted external requests, worker
  traffic to external origins, external writes, or HTTP errors. Chromium has no
  uncaught page errors or unexpected console errors. The recorded warning is
  `WebR is using PostMessage communication channel, nested R REPLs are not
  available.` Frame rate was not measured. WebKit is not covered by Chromium
  NetLog; its startup, uploads, calculations, and image rendering pass.
- Browser diagnostics now persist beside each test as `browser-diagnostics.json`
  or `webkit-startup.json`, as well as in report attachments. Failure traces and
  screenshots are retained when a test fails.

### Current Screenshots

Paths relative to `tests/browser/artifacts/results/`:

- `projections-example-number-4691f-entry-and-total-grade-plots-desktop/desktop-1280-layout.png`
- `mobile-mobile-continuous-i-01368--and-plot-table-stay-usable-mobile/mobile-430-layout.png`
- `mobile-mobile-continuous-i-01368--and-plot-table-stay-usable-mobile/mobile-chart.png`
- `mobile-mobile-continuous-i-01368--and-plot-table-stay-usable-mobile/mobile-chart-caption.png`
- `safari-WebKit-renders-proj-673e3-nputs-downloads-and-resizes-webkit/webkit-1280-layout.png`
- `safari-WebKit-renders-proj-673e3-nputs-downloads-and-resizes-webkit/webkit-430-layout.png`

The HTML report is `tests/browser/artifacts/report/index.html`.

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
