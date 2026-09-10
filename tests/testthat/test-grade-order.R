test_that("common grades are suggested in progression rather than file order", {
  suggestion <- suggest_grade_order(c("10", "2", "K", "12", "1", "PK4", "PK3", "2"))
  expect_equal(suggestion$grades, c("PK3", "PK4", "K", "1", "2", "10", "12"))
  expect_length(suggestion$unmatched, 0)
  expect_length(suggestion$ambiguous, 0)
})

test_that("aliases are used for sorting without rewriting original labels", {
  suggestion <- suggest_grade_order(c("Grade 10", "02", "Kindergarten",
    "Pre-K", "1st Grade", "TK", "Preschool"))
  expect_equal(suggestion$grades, c("Preschool", "Pre-K", "TK", "Kindergarten",
    "1st Grade", "02", "Grade 10"))
  expect_equal(suggest_grade_order(c("third grade", "GRADE_2", "KG", "First"))$grades,
    c("KG", "First", "GRADE_2", "third grade"))
})

test_that("the lookup handles all grades through twelve and zero-padded labels", {
  grades <- c("00", sprintf("%02d", 1:12))
  expect_equal(suggest_grade_order(rev(grades))$grades, grades)
  expect_equal(suggest_grade_order(c("G12", "grade11", "9th", "G 10"))$grades,
    c("9th", "G 10", "grade11", "G12"))
})

test_that("unrecognized labels retain the complete file order for review", {
  grades <- c("2", "Ungraded", "K", "1", "Adult Education")
  suggestion <- suggest_grade_order(grades)
  expect_identical(suggestion$grades, grades)
  expect_equal(suggestion$unmatched, c("Ungraded", "Adult Education"))
  expect_length(suggestion$ambiguous, 0)
})

test_that("aliases for the same level are not silently merged or ordered", {
  grades <- c("2", "K", "KG", "1")
  suggestion <- suggest_grade_order(grades)
  expect_identical(suggestion$grades, grades)
  expect_setequal(suggestion$ambiguous, c("K", "KG"))
  expect_length(suggestion$unmatched, 0)
  expect_setequal(suggest_grade_order(c("PK4", "PK", "K"))$ambiguous,
    c("PK4", "PK"))
})

test_that("negative numbers, decimals and grade bands are not numeric aliases", {
  grades <- c("-1", "1.0", "1-2", "13", "K-12")
  suggestion <- suggest_grade_order(grades)
  expect_identical(suggestion$grades, grades)
  expect_identical(suggestion$unmatched, grades)
})

test_that("factor levels do not override the lookup and empty input is safe", {
  expect_equal(suggest_grade_order(factor(c("10", "2", "K")))$grades,
    c("K", "2", "10"))
  expect_equal(suggest_grade_order(c(" K ", "1", "K"))$grades, c("K", "1"))
  expect_equal(suggest_grade_order(c(NA_character_, "", " ")),
    list(grades = character(), unmatched = character(), ambiguous = character()))
})
