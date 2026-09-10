example_history <- function() {
  data.frame(
    year = rep(2021:2023, each = 3),
    grade = rep(c("K", "1", "2"), 3),
    enrollment = c(100, 90, 80, 110, 95, 88, 120, 99, 91)
  )
}

suggest_grade_order <- function(grades) {
  grades <- unique(trimws(as.character(grades)))
  grades <- grades[!is.na(grades) & nzchar(grades)]
  keys <- tolower(trimws(gsub("[[:space:]_-]+", " ", grades)))
  # A negative code or grade band is not the same as an elementary grade.
  keys[grepl("^[-+]", grades)] <- NA_character_
  aliases <- list(
    c("ps", "preschool", "pre school"),
    c("pk3", "pk 3", "prek3", "prek 3", "pre k3", "pre k 3",
      "prekindergarten3", "prekindergarten 3", "pre kindergarten 3"),
    c("pk", "prek", "pre k", "prekindergarten", "pre kindergarten",
      "pk4", "pk 4", "prek4", "prek 4", "pre k4", "pre k 4",
      "prekindergarten4", "prekindergarten 4", "pre kindergarten 4"),
    c("tk", "transitional kindergarten"),
    c("k", "kg", "kindergarten", "0", "00")
  )
  ordinal <- paste0(1:12, c("st", "nd", "rd", rep("th", 9)))
  words <- c("first", "second", "third", "fourth", "fifth", "sixth",
    "seventh", "eighth", "ninth", "tenth", "eleventh", "twelfth")
  aliases <- c(aliases, lapply(1:12, function(grade) {
    c(as.character(grade), sprintf("%02d", grade),
      paste("grade", grade), paste0("grade", grade),
      paste("g", grade), paste0("g", grade),
      ordinal[grade], paste(ordinal[grade], "grade"),
      words[grade], paste(words[grade], "grade"))
  }))
  lookup <- setNames(rep(seq_along(aliases), lengths(aliases)),
    unlist(aliases, use.names = FALSE))
  ranks <- unname(lookup[keys])
  unmatched <- grades[is.na(ranks)]
  ambiguous <- grades[!is.na(ranks) &
    (duplicated(ranks) | duplicated(ranks, fromLast = TRUE))]
  if (!length(unmatched) && !length(ambiguous)) {
    grades <- grades[order(ranks)]
  }
  list(grades = grades, unmatched = unmatched, ambiguous = ambiguous)
}

read_upload <- function(path, name) {
  extension <- tolower(tools::file_ext(name))
  if (extension == "csv") {
    data <- read.csv(path, colClasses = "character", check.names = FALSE)
  } else if (extension %in% c("xlsx", "xls")) {
    if (!requireNamespace("readxl", quietly = TRUE)) {
      stop("Excel import is unavailable because the readxl package is not installed. Upload a CSV file or contact the application administrator.",
        call. = FALSE)
    }
    data <- as.data.frame(readxl::read_excel(path, col_types = "text"))
  } else {
    stop("Upload a CSV or Excel (.xlsx, .xls) file.", call. = FALSE)
  }
  names(data) <- tolower(trimws(names(data)))
  if (anyDuplicated(names(data))) {
    stop("Column headings must be unique.", call. = FALSE)
  }
  data
}

validate_table <- function(data, type) {
  columns <- switch(type,
    history = c("year", "grade", "enrollment"),
    base = c("grade", "enrollment"),
    entry = c("year", "enrollment")
  )
  if (!all(columns %in% names(data))) {
    stop("Required columns: ", paste(columns, collapse = ", "), call. = FALSE)
  }
  if (!nrow(data)) stop("The table is empty.", call. = FALSE)
  data <- data[intersect(c("year", "grade", "enrollment"), names(data))]
  data$enrollment <- suppressWarnings(as.numeric(data$enrollment))
  if (any(!is.finite(data$enrollment) | data$enrollment < 0)) {
    stop("Enrollment must contain only non-negative, finite numbers; no blanks.",
      call. = FALSE)
  }
  if ("year" %in% names(data)) {
    data$year <- suppressWarnings(as.numeric(data$year))
    if (any(!is.finite(data$year) | data$year != floor(data$year) |
      data$year < 1900 | data$year > 9999)) {
      stop("Years must be whole numbers from 1900 to 9999 (e.g. 2023).",
        call. = FALSE)
    }
  }
  if ("grade" %in% names(data)) {
    data$grade <- trimws(as.character(data$grade))
    if (anyNA(data$grade) || any(!nzchar(data$grade))) {
      stop("Grade labels cannot be blank.", call. = FALSE)
    }
  }
  keys <- switch(type, history = c("year", "grade"),
    base = "grade", entry = "year")
  if (anyDuplicated(data[keys])) {
    stop("Duplicate rows for ", paste(keys, collapse = " / "), ".",
      call. = FALSE)
  }
  data
}

align_entry <- function(data, start_year, horizon) {
  data <- validate_table(data, "entry")
  years <- start_year + seq_len(horizon)
  if (!setequal(data$year, years)) {
    stop("Entry must contain exactly one row for each projected year: ",
      paste(years, collapse = ", "), ".", call. = FALSE)
  }
  data$enrollment[match(years, data$year)]
}

build_projection <- function(history, base, grades, start_year, horizon,
                             entry, method) {
  history <- validate_table(history, "history")
  if (length(horizon) != 1 || !is.finite(horizon) ||
    horizon != floor(horizon) || horizon < 1 || horizon > 30) {
    stop("Horizon must be a whole number from 1 to 30.", call. = FALSE)
  }
  if (length(start_year) != 1 || !is.finite(start_year) ||
    start_year != floor(start_year) || start_year < max(history$year) ||
    start_year + horizon > 9999) {
    stop("The base year must be at least the latest historical year, with projected years no later than 9999.",
      call. = FALSE)
  }
  if (length(grades) < 2 || anyDuplicated(grades) ||
    !setequal(grades, history$grade)) {
    stop("Grade order must list every historical grade exactly once, lowest first.",
      call. = FALSE)
  }
  if (is.null(base)) base <- history[history$year == start_year, ]
  base <- validate_table(base, "base")
  if (!setequal(base$grade, grades)) {
    stop("Base enrollment must include every grade exactly once.", call. = FALSE)
  }
  if ("year" %in% names(base) && any(base$year != start_year)) {
    stop("Base year does not match the selected starting year.", call. = FALSE)
  }
  base <- base[match(grades, base$grade), ]
  base$year <- start_year
  if (length(entry) != horizon || any(!is.finite(entry) | entry < 0)) {
    stop("Entry needs one non-negative, finite count per projected year.",
      call. = FALSE)
  }
  ratios <- enrollcast::progression_ratios(history,
    method = method, grade_order = grades)
  if (any(!is.finite(ratios$ratio))) {
    stop("Cannot project: progression ratios are not finite. Check missing grade/year rows and zero feeder enrollment.",
      call. = FALSE)
  }
  projection <- enrollcast::project_enrollment(base, ratios,
    horizon = horizon, entry = entry, start_year = start_year)
  if (any(!is.finite(projection$enrollment))) {
    stop("Projected enrollment exceeds the supported numeric range. Review the historical data for unusually large grade progression ratios.",
      call. = FALSE)
  }
  list(history = history, base = base, ratios = ratios,
    projection = projection, grades = grades,
    entry = data.frame(year = start_year + seq_len(horizon), enrollment = entry))
}
