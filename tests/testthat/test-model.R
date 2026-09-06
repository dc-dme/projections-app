test_that("templates produce the documented enrollcast projection", {
  history <- example_history()
  result <- build_projection(history, NULL, c("K", "1", "2"),
    2023, 3, c(125, 130, 128), "mean")
  expect_equal(result$projection$year, rep(2024:2026, each = 3))
  expect_equal(result$projection$enrollment[1:3],
    c(125, 111, 99 * mean(c(88 / 90, 91 / 95))))
  expect_equal(result$entry$enrollment, c(125, 130, 128))
})

test_that("invalid counts, keys and years are rejected", {
  x <- example_history()
  expect_error(validate_table(x[0, ], "history"), "empty")
  expect_error(validate_table(x[ , -1], "history"), "year")
  expect_error(validate_table(rbind(x, x[1, ]), "history"), "Duplicate")
  for (bad in c(-1, NA, Inf, NaN)) {
    y <- x
    y$enrollment[1] <- bad
    expect_error(validate_table(y, "history"), "Enrollment")
  }
  x$year[1] <- 2021.5
  expect_error(validate_table(x, "history"), "Years")
  x <- example_history()
  x$grade[1] <- ""
  expect_error(validate_table(x, "history"), "Grade")
})

test_that("entry years are aligned rather than taken in file order", {
  entry <- data.frame(year = c(2025, 2024), enrollment = c(130, 125))
  expect_equal(align_entry(entry, 2023, 2), c(125, 130))
  expect_error(align_entry(entry, 2022, 2), "exactly")
  expect_error(align_entry(rbind(entry, entry[1, ]), 2023, 2), "Duplicate")
})

test_that("projection checks base, grade order, horizon and entry", {
  x <- example_history()
  run <- function(history = x, base = NULL, grades = c("K", "1", "2"),
                  year = 2023, horizon = 2, entry = c(125, 130)) {
    build_projection(history, base, grades, year, horizon, entry, "mean")
  }
  expect_error(run(grades = c("K", "1")), "Grade order")
  expect_error(run(grades = c("K", "1", "1", "2")), "Grade order")
  expect_error(run(year = 2022), "base year")
  expect_error(run(horizon = 0), "Horizon")
  expect_error(run(entry = 125), "Entry")
  expect_error(run(entry = c(-1, 130)), "Entry")
  base <- subset(x, year == 2023)
  expect_error(run(base = base[-1, ]), "Base")
  base$year <- 2024
  expect_error(run(base = base), "Base year")
  base$year <- 2023
  base$enrollment <- c(200, 180, 160)
  expect_equal(run(base = base)$base$enrollment, c(200, 180, 160))
  x$enrollment[x$grade == "K"] <- 0
  expect_warning(expect_error(run(history = x), "finite|infinite"),
    "infinite or NaN")
})

test_that("CSV imports preserve labels and normalize column headings", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path))
  writeLines(c("Year,Grade,Enrollment", "2023,K,100"), path)
  expect_equal(read_upload(path, "test.csv"),
    data.frame(year = "2023", grade = "K", enrollment = "100"))
  expect_error(read_upload(path, "test.txt"), "CSV or Excel")
})

test_that("Excel uploads read the first worksheet as text", {
  path <- readxl::readxl_example("datasets.xlsx")
  data <- read_upload(path, "enrollment.xlsx")
  expect_equal(nrow(data), 32)
  expect_true(all(vapply(data, is.character, logical(1))))
  expect_identical(names(data), tolower(names(data)))
})

test_that("history gaps are surfaced and never bridged", {
  history <- example_history()
  history$year[history$year == 2021] <- 2019
  expect_warning(result <- build_projection(history, NULL,
    c("K", "1", "2"), 2023, 1, 125, "mean"), "gap|consecutive|adjacent")
  expect_equal(result$ratios$ratio, c(99 / 110, 91 / 95))
})
