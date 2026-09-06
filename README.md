# enrollcast Enrollment Planner

A Shiny app for projecting one school's or district's grade-level enrollment
with `enrollcast`. Includes synthetic example data, CSV/Excel uploads, CSV
templates, input checks, charts, progression ratios, and downloadable projections.

## Run

Requires R and `enrollcast` 0.1.0 or later. Install the dependencies in R:

```r
install.packages(c("shiny", "bslib", "ggplot2", "readxl", "testthat"))
# Install enrollcast from its distribution source if not already installed.
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
or analytics, but Shiny stores uploads in temporary session files. Hosting
infrastructure may have its own logs and retention rules. This repository does
not configure authentication or production hosting. Shiny's default upload size
limit applies (normally 5 MB per file).

## Development

```sh
Rscript tests/testthat.R
```

`R/model.R` contains parsing, validation, and the enrollcast integration;
`R/app.R` contains the UI and session-scoped reactive server. `app.R` launches it.
