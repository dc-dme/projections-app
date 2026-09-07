# enrollcast Enrollment Planner

A Shiny app for projecting one school's or district's grade-level enrollment
with `enrollcast`. Includes synthetic example data, CSV/Excel uploads, CSV
templates, input checks, charts, progression ratios, and downloadable projections.

## Run

Requires R and `enrollcast` 0.1.0 or later. Install the dependencies in R:

```r
install.packages(c("shiny", "bslib", "ggplot2", "readxl", "testthat"))
install.packages("enrollcast", repos = c(
  "https://localopen.r-universe.dev", "https://cloud.r-project.org"
))
shiny::runApp()
```

Run from this repository's root. Excel support requires `readxl`; other app
features work without it. No external font service or database is required.

## Workflow

1. Explore the example or upload history. Download templates from the first tab.
2. Enter the exact low-to-high grade order. Default base counts come from the
   latest historical year; a separate base upload can override them.
3. Choose a horizon and ratio method. Supply entry counts by year, upload them,
   or explicitly hold them at the base entry-grade count.
4. Explore totals or a grade, inspect ratios, and download full-precision results.

## File Format

Use long-format tables, not a year-per-column layout. Column headings are
case-insensitive and surrounding whitespace is removed. Excel reads the first
worksheet. Additional columns are ignored, not used for grouping.

| Input | Required columns | Rules |
| --- | --- | --- |
| History | year, grade, enrollment | Unique grade/year rows; at least one adjacent-year pair |
| Base | grade, enrollment | Every historical grade exactly once; optional year must match selected base year |
| Entry | year, enrollment | Exactly one row per projected year; sorted by year automatically |

Use integer year labels (2023, not 2023-24), consistently identifying either the
start or end of the academic year. Counts must be finite and non-negative;
missing counts are rejected, not silently set to zero. Grade labels must match
exactly. The lowest grade is the sole entry grade. Templates contain synthetic
K-2 counts; replace all rows for your grade span.

The app passes grade order explicitly to `progression_ratios()` and supplies
entry counts explicitly to `project_enrollment()`. History gaps trigger visible
package warnings. Undefined progression ratios block projections. Base years
cannot precede the latest historical year. Fractional counts are retained for
calculation and export; displayed counts are rounded.

## Limits and Privacy

Standard deterministic grade-progression projections only: no swing/recovery,
scenario comparisons, uncertainty intervals, or automatic entry estimation.
Results update automatically, so changes cannot leave an old projection labeled
with new assumptions. A separate base may differ from history and is shown as
a distinct diamond on the chart.

Upload aggregate enrollment, never student records. The app has no persistence
or analytics. In conventional Shiny, uploads are stored in temporary files on
the machine running R. In the Shinylive version, R runs in the browser and files
are processed in its virtual filesystem; enrollment contents are not sent to a
remote R server. Hosting services still receive ordinary asset requests and may
log them. Do not embed credentials or private data in this public application.
Shiny's default upload size limit applies (normally 5 MB per file).

Refreshing or closing a browser session can discard inputs. Download results
before leaving. There is no central storage, authentication, or automatic save.

## Development

```sh
Rscript tests/testthat.R
```

`R/model.R` contains parsing, validation, and the enrollcast integration;
`R/app.R` contains the UI and session-scoped reactive server. `app.R` launches it.

## Build the Browser Version

The same application can run entirely in a browser through Shinylive. No
separate Wasm build of enrollcast is needed: its binary is obtained from
**https://localopen.r-universe.dev**, with no fallback to the retiring repository.

Use R 4.6.1 and Node.js 24 or newer. From the repository root:

```sh
Rscript scripts/setup-build.R
Rscript scripts/test-native.R
Rscript scripts/export-shinylive.R
npm ci
npx playwright install chromium webkit
npm run test:browser
```

The setup restores `scripts/renv.lock` into `.build-library/`, then verifies and
installs the canonical enrollcast source archive using its pinned checksum. It does not
activate renv for the application or change your regular R library. Linux
builds need libarchive, libcurl, and OpenSSL development libraries; the workflow
installs them. Playwright can install its Linux system dependencies with
`npx playwright install --with-deps chromium webkit`.

The exporter stages only `app.R`, `R/`, and `www/`, then creates `site/`.
It replaces only a directory marked as its own generated output, and only after
artifact validation succeeds. Do not store hand-written files in `site/`.
Tests, build dependencies, and Git metadata are not published.

To preview the generated site:

```sh
npm run preview
```

Open <http://127.0.0.1:4173/projections-app/>. This serves static files only,
under the same subpath as the intended Pages site, without an R server or custom
cross-origin isolation headers. Opening `site/index.html` as a local file is not
supported; service workers require localhost or HTTPS.

The initial visit downloads the browser R runtime and its dependencies, so
startup is slower than a conventional webpage. Packages are bundled into the
site rather than installed from external repositories during startup. Browser
tests for Chromium block external requests and audit worker-inclusive network logs. This is
not a promise of offline operation or persistent browser caching.

## GitHub Pages

The destination repository is `dc-dme/projections-app`. Its expected default
Pages URL is <https://dc-dme.github.io/projections-app/> once publication is enabled.

1. Commit and push the reviewed changes to GitHub.
2. In **Settings > Pages**, select **GitHub Actions** as the build source.
3. In **Settings > Secrets and variables > Actions > Variables**, create the
   repository variable `PAGES_ENABLED` with the value `true`.
4. Run **Test and deploy Shinylive** from the Actions tab on `main`, or push an
   update to `main`.

Until `PAGES_ENABLED` is set, the workflow only builds and tests. Pull requests
never deploy. The deployment job can publish only after native tests, Wasm
artifact checks, Chromium tests, and a separate macOS WebKit test succeed. Both
browser jobs test the same exported site artifact. The previous published site remains
available if a build fails. Generated assets are uploaded as a Pages artifact,
not committed to a separate branch. Disabling the variable prevents future
deployments; it does not unpublish an existing site.

Action revisions are pinned. The build job has read-only repository permissions;
only the deployment job receives Pages write and OIDC permissions. No additional
deployment secret is required. Failure traces, screenshots, network diagnostics,
and `build-info.json` are retained as workflow artifacts for seven days. Tests
use synthetic data only.

## Versions and Upgrades

The tested export uses Shinylive **0.5.0**, assets **0.10.12**, and browser R
**4.6.0**, with enrollcast **0.1.0**. Native build dependencies are recorded in
`scripts/renv.lock`; runtime selections are in `scripts/build-config.R`.
`scripts/wasm-lock.json` records additional Wasm package versions, source URLs,
and SHA-256 hashes, plus hashes of the core runtime files and service worker.
The selected Shinylive assets supply the core Shiny packages.
Each published site includes the Wasm manifest at `build-info.json`.

The exporter intentionally fails if package artifacts change, including a
repository rebuild that preserves the version number. These locks detect drift;
they do not make upstream repositories permanent archives. Retain deployment
artifacts separately if long-term bit-for-bit rebuilding is required.

For an intentional upgrade, update the isolated library and native lockfile,
review runtime compatibility, and update `scripts/build-config.R` when changing
the runtime or the enrollcast source URL/checksum. Obtain the new checksum from
the canonical repository's package metadata and review the corresponding source
revision. Then run:

```sh
Rscript scripts/export-shinylive.R --update-wasm-lock
Rscript scripts/test-native.R
npm run test:browser
```

Review the lockfile differences before committing. CI never updates locks
automatically. Missing binaries should be resolved at the package/runtime level,
not by silently dropping Excel support or switching to another enrollcast source.

`www/browser-downloads.js` is loaded only under webR. It works around Chromium
download requests bypassing Shinylive's virtual service-worker routes by fetching
the generated file inside the app and downloading a local Blob. Native Shiny
downloads are unchanged. Reassess this workaround when upgrading Shinylive.

The webR entry point pre-renders the static UI before the first HTTP request,
retaining its Bootstrap theme and dependencies. The chart uses `renderImage()`
to draw the same ggplot directly to a temporary PNG. These avoid the deeper
rendering call stacks that overflow in Safari; enrollment calculations are unchanged.
Native Shiny retains its normal UI initialization. Temporary chart images are
removed after delivery or on rendering failure.

Browser coverage uses desktop Chromium, Pixel-sized Chromium emulation, and
macOS WebKit. The WebKit test checks startup, projections, manual entry, Excel
entry uploads, downloads, and resizing. Physical Safari/iOS devices, Firefox,
and the final HTTPS deployment still require manual verification. See
`tests/browser/NOTES.md` for the remaining checklist.
