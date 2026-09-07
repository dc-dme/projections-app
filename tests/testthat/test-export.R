test_that("export staging includes only application runtime files", {
  source(test_path("../../scripts/export-helpers.R"), local = TRUE)
  staged <- tempfile()
  on.exit(unlink(staged, recursive = TRUE))
  stage_app(test_path("../.."), staged)
  expect_setequal(list.files(staged, recursive = TRUE, all.files = TRUE),
    c("app.R", "R/app.R", "R/model.R", "www/app.css",
      "www/browser-downloads.js"))
  expect_identical(readLines(file.path(staged, "app.R")),
    readLines(test_path("../../app.R")))
})

test_that("missing Wasm binaries fail export validation", {
  source(test_path("../../scripts/export-helpers.R"), local = TRUE)
  root <- tempfile()
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE))
  expect_error(validate_wasm(list(), root), "Missing")
  incomplete <- list(enrollcast = list(path = "missing.tgz"),
    readxl = list(path = "missing.tgz"), ggplot2 = list(path = "missing.tgz"))
  expect_error(validate_wasm(incomplete, root), "Missing")
})

test_that("checksums detect same-version artifact replacements", {
  source(test_path("../../scripts/export-helpers.R"), local = TRUE)
  path <- tempfile()
  on.exit(unlink(path))
  writeLines("original artifact", path)
  checksum <- sha256_file(path)
  expect_invisible(verify_checksum(path, checksum))
  writeLines("rebuilt artifact", path)
  expect_error(verify_checksum(path, checksum), "Checksum mismatch")
})

test_that("core runtime changes alter the locked asset hashes", {
  source(test_path("../../scripts/export-helpers.R"), local = TRUE)
  root <- tempfile()
  dir.create(file.path(root, "shinylive", "webr"), recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE))
  writeLines("worker", file.path(root, "shinylive-sw.js"))
  core <- file.path(root, "shinylive", "webr", "R.wasm")
  writeLines("original runtime", core)
  original <- runtime_hashes(root)
  expect_named(original, c("shinylive-sw.js", "shinylive/webr/R.wasm"))
  writeLines("changed runtime", core)
  expect_false(identical(runtime_hashes(root), original))
})

test_that("the download workaround is not loaded by native Shiny", {
  expect_false(grepl("browser-downloads.js", htmltools::renderTags(ui)$head,
    fixed = TRUE))
})

test_that("unmarked sites are preserved and marked exports are replaced", {
  source(test_path("../../scripts/export-helpers.R"), local = TRUE)
  root <- tempfile()
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE))
  output <- file.path(root, "output")
  site <- file.path(root, "site")
  dir.create(output)
  dir.create(site)
  writeLines("new", file.path(output, "index.html"))
  writeLines("old", file.path(site, "index.html"))
  expect_error(publish_site(output, site), "Refusing")
  expect_equal(readLines(file.path(site, "index.html")), "old")
  file.create(file.path(site, ".enrollcast-export"))
  publish_site(output, site)
  expect_equal(readLines(file.path(site, "index.html")), "new")
})

test_that("a failed replacement restores the previous export", {
  source(test_path("../../scripts/export-helpers.R"), local = TRUE)
  root <- tempfile()
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE))
  output <- file.path(root, "output")
  site <- file.path(root, "site")
  dir.create(output)
  dir.create(site)
  file.create(file.path(site, ".enrollcast-export"))
  writeLines("old", file.path(site, "index.html"))
  writeLines("new", file.path(output, "index.html"))
  failed <- FALSE
  environment(publish_site)$file.rename <- function(from, to) {
    if (identical(to, site) && !failed) {
      failed <<- TRUE
      return(FALSE)
    }
    base::file.rename(from, to)
  }
  expect_error(publish_site(output, site), "replacement")
  expect_equal(readLines(file.path(site, "index.html")), "old")
})
