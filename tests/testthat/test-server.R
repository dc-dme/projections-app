test_that("example workflow renders results and invalid edits clear them", {
  shiny::testServer(server, {
    session$setInputs(source = "example", base_mode = "latest",
      grades = "K, 1, 2", horizon = 2, entry_mode = "constant",
      method = "mean", view_grade = "__total__", school = "Test district")
    expect_equal(projection()$entry$enrollment, c(120, 120))
    expect_match(output$summary$html, "310")
    expect_match(output$projection_table, "2024")
    expect_true(is.list(output$projection_plot))
    session$setInputs(grades = "K, 1")
    expect_match(result()$error, "Grade order")
    expect_error(projection(), "Grade order")
  })
})

test_that("a one-year projection uses a singular year label", {
  shiny::testServer(server, {
    session$setInputs(source = "example", base_mode = "latest",
      grades = "K, 1, 2", horizon = 1, entry_mode = "constant",
      method = "mean", view_grade = "__total__", school = "Test")
    expect_match(output$entry_context$html,
      "Entry grade: K. Projected year: 2024. Base year: 2023.",
      fixed = TRUE)
  })
})

test_that("manual entry changes propagate to projected cohorts", {
  shiny::testServer(server, {
    session$setInputs(source = "example", base_mode = "latest",
      grades = "K, 1, 2", horizon = 2, entry_mode = "manual",
      method = "mean", view_grade = "__total__", school = "Test")
    expect_match(result()$error, "Entry")
    session$setInputs(entry_2024 = 125, entry_2025 = 130)
    expect_equal(projection()$projection$enrollment[c(1, 4)], c(125, 130))
    expect_match(output$entry_context$html, "Projected years: 2024 to 2025",
      fixed = TRUE)
    expect_equal(projection()$entry$year, 2024:2025)
  })
})

test_that("missing upload is actionable and does not expose old results", {
  shiny::testServer(server, {
    session$setInputs(source = "upload", base_mode = "latest",
      grades = "K, 1, 2", horizon = 2, entry_mode = "constant", method = "mean")
    expect_match(history_state()$error, "Choose a file")
    expect_match(output$result_status$html, "Choose a file")
  })
})

test_that("uploaded history, base and entry flow through to exports", {
  paths <- replicate(3, tempfile(fileext = ".csv"))
  on.exit(unlink(paths))
  write.csv(example_history(), paths[1], row.names = FALSE)
  write.csv(data.frame(grade = c("K", "1", "2"), enrollment = c(200, 180, 160)),
    paths[2], row.names = FALSE)
  write.csv(data.frame(year = c(2025, 2024), enrollment = c(140, 130)),
    paths[3], row.names = FALSE)
  shiny::testServer(server, {
    session$setInputs(source = "upload", base_mode = "upload", base_year = 2023,
      history_file = list(datapath = paths[1], name = "history.csv"),
      base_file = list(datapath = paths[2], name = "base.csv"),
      entry_file = list(datapath = paths[3], name = "entry.csv"),
      grades = "K, 1, 2", horizon = 2, entry_mode = "upload",
      method = "mean", view_grade = "1", school = "Uploaded district")
    expect_equal(projection()$base$enrollment, c(200, 180, 160))
    expect_equal(projection()$entry$enrollment, c(130, 140))
    expect_equal(read.csv(output$projection_download), projection()$projection)
    expect_equal(read.csv(output$ratios_download,
      colClasses = c("character", "character", "numeric")), projection()$ratios)
    expect_equal(read.csv(output$history_template), example_history())
    expect_equal(nrow(read.csv(output$base_template)), 3)
    expect_equal(read.csv(output$entry_template)$year, 2024:2025)
    expect_true(is.list(output$projection_plot))
  })
})
