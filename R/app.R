library(shiny)
library(bslib)
library(ggplot2)

ui <- page_fluid(
  title = "Enrollment Projections Calculator",
  theme = bs_theme(version = 5, bg = "#ffffff", fg = "#243238",
    primary = "#155e63", base_font = "system-ui"),
  tags$head(tags$link(rel = "stylesheet", href = "app.css")),
  if (grepl("emscripten", R.version$platform)) {
    tags$head(tags$script(src = "browser-downloads.js"))
  },
  tags$a(class = "skip-link", href = "#main-content", "Skip to main content"),
  tags$header(class = "service-header",
    div(class = "page-width header-inner",
      tags$span(class = "service-name", "Enrollment planning"),
      tags$a(href = "#results", "View projection")
    )
  ),
  tags$main(id = "main-content", tabindex = "-1", class = "page-width",
    div(class = "page-intro",
      tags$h1("Project enrollment"),
      tags$p("Use your enrollment history to estimate future enrollment by grade."),
      tags$p(class = "privacy-note", "Use aggregate counts only. Do not include student names or personal information.")
    ),
    div(class = "planner-layout",
      tags$section(id = "inputs", class = "input-panel",
        `aria-label` = "Projection inputs",
        tags$section(class = "form-section", `aria-labelledby` = "data-heading",
          tags$h2(id = "data-heading", "Enrollment data"),
          radioButtons("source", "Data source",
            c("Use example data" = "example", "Upload enrollment data" = "upload"),
            inline = TRUE, width = "100%"),
          fileInput("history_file", "Upload historical enrollment",
            accept = c(".csv", ".xlsx", ".xls"), width = "100%"),
          tags$p(class = "hint", "CSV or Excel. One school or district per file."),
          downloadButton("history_template", "Download CSV template",
            class = "btn-link text-download"),
          uiOutput("history_status"),
          textInput("grades", "Grades, lowest to highest", "K, 1, 2", width = "100%"),
          uiOutput("grade_order_hint"),
          tags$details(id = "history_details",
            tags$summary("File format and data preview"),
            div(class = "disclosure-content",
              tags$p("Required columns: year, grade, enrollment. Include one row per grade per year, with at least two consecutive years."),
              tags$p("Use a four-digit year, such as 2023 for 2023-24, consistently across files. Enter 0 only for known zero enrollment; do not leave counts blank."),
              tags$p("Column headings are case-insensitive. Only the first Excel worksheet is read. The template contains illustrative K-2 data; replace all rows with your own data."),
              tags$p(class = "hint", "Preview: up to 20 records."),
              div(class = "table-scroll", tabindex = "0",
                `aria-label` = "Historical enrollment preview",
                tableOutput("history_preview"))
            )
          )
        ),
        tags$section(class = "form-section", `aria-labelledby` = "assumptions-heading",
          tags$h2(id = "assumptions-heading", "Projection assumptions"),
          numericInput("horizon", "Projection period (years)", 5,
            min = 1, max = 30, step = 1, width = "100%"),
          uiOutput("entry_context"),
          tags$p(class = "hint", "Entry enrollment supplies future cohorts for your lowest grade."),
          radioButtons("entry_mode", "Entry enrollment source",
            c("Hold constant at base-year entry enrollment" = "constant",
              "Enter enrollment for each projected year" = "manual",
              "Upload entry enrollment" = "upload"), width = "100%"),
          conditionalPanel("input.entry_mode === 'manual'",
            div(id = "entry_fields", class = "entry-grid")),
          conditionalPanel("input.entry_mode === 'upload'",
            fileInput("entry_file", "Upload entry enrollment",
              accept = c(".csv", ".xlsx", ".xls"), width = "100%"),
            tags$p(class = "hint", "Columns: year, enrollment. One row for each projected year, with no additional years."),
            downloadButton("entry_template", "Download entry template",
              class = "btn-link text-download")
          ),
          tags$details(id = "advanced_details",
            tags$summary("Base enrollment and calculation settings"),
            div(class = "disclosure-content",
              tags$p("By default, projections start from your most recent historical year and use mean progression ratios."),
              radioButtons("base_mode", "Base enrollment source",
                c("Most recent historical year" = "latest",
                  "Upload a separate file" = "upload"), width = "100%"),
              conditionalPanel("input.base_mode === 'upload'",
                fileInput("base_file", "Upload base enrollment",
                  accept = c(".csv", ".xlsx", ".xls"), width = "100%"),
                numericInput("base_year", "Base year", 2023, min = 1900, max = 9998),
                tags$p(class = "hint", "Columns: grade, enrollment. Include every grade. An optional year column must match the base year.")
              ),
              downloadButton("base_template", "Download base template",
                class = "btn-link text-download"),
              selectInput("method", "Grade progression ratio method",
                c("Average (mean)" = "mean", "Median" = "median",
                  "Geometric mean" = "geometric", "Most recent transition" = "last"),
                selectize = FALSE, width = "100%"),
              tags$p(class = "hint", "All available consecutive-year transitions are used, except when selecting the most recent transition."),
              textInput("school", "School or district name (optional)",
                "", placeholder = "For example, Central School District", width = "100%")
            )
          ),
          tags$a(class = "view-results-link", href = "#results", "View projection")
        )
      ),
      tags$section(id = "results", tabindex = "-1", class = "results-panel",
        `aria-labelledby` = "results-heading",
        tags$h2(id = "results-heading", "Your projection"),
        uiOutput("result_status"),
        conditionalPanel("output.projection_ready === 'ready'",
          div(class = "projection-body",
            uiOutput("summary"),
            div(class = "results-toolbar",
              selectInput("view_grade", "Show in chart",
                c("Total enrollment" = "__total__"), selectize = FALSE),
              downloadButton("projection_download", "Download projections (CSV)",
                class = "btn-primary")
            ),
            plotOutput("projection_plot", height = "360px"),
            tags$p(class = "hint chart-caption", "Solid line: observed enrollment. Dashed line: projection. Diamond: base enrollment."),
            tags$details(id = "projection_details",
              tags$summary("View projected enrollment table"),
              div(class = "disclosure-content",
                tags$p(class = "hint", "Counts are rounded to the nearest student. CSV downloads retain unrounded values."),
                div(class = "table-scroll", tabindex = "0",
                  `aria-label` = "Projected enrollment by year and grade",
                  tableOutput("projection_table"))
              )
            ),
            tags$details(id = "ratios_details",
              tags$summary("Review progression ratios"),
              div(class = "disclosure-content",
                tags$p("A ratio of 1 means no change in cohort enrollment between grades; above 1 indicates growth and below 1 indicates decline."),
                tableOutput("ratios_table"),
                downloadButton("ratios_download", "Download ratios (CSV)",
                  class = "btn-link text-download")
              )
            )
          )
        )
      )
    )
  ),
  tags$footer(class = "service-footer",
    div(class = "page-width",
      tags$p("For planning use only. Projections assume historical patterns continue and do not include uncertainty intervals."),
      tags$p("Entry counts are your assumptions. Consider birth cohorts, housing changes, lottery seats, and other local factors.")
    )
  )
)

server <- function(input, output, session) {
  observeEvent(input$history_file, {
    updateRadioButtons(session, "source", selected = "upload")
  })
  upload <- function(file) {
    if (is.null(file)) {
      stop("Choose a file to continue.", call. = FALSE)
    }
    read_upload(file$datapath, file$name)
  }
  history_state <- reactive({
    tryCatch(
      list(
        data = validate_table(
          if (input$source == "example") {
            example_history()
          } else {
            upload(input$history_file)
          },
          "history"
        )
      ),
      error = function(e) list(error = conditionMessage(e))
    )
  })
  grade_suggestion <- reactive({
    state <- history_state()
    req(state$data)
    suggest_grade_order(state$data$grade)
  })
  # New history gets a new suggestion; editing grades or assumptions does not.
  observeEvent(grade_suggestion(), {
    updateTextInput(session, "grades",
      value = paste(grade_suggestion()$grades, collapse = ", "))
  }, priority = 120)
  output$grade_order_hint <- renderUI({
    if (is.null(history_state()$data)) {
      return(tags$p(class = "hint", "List every grade once, separated by commas. Labels must match your file."))
    }
    suggestion <- grade_suggestion()
    entered <- trimws(strsplit(input$grades, ",", fixed = TRUE)[[1]])
    if (!identical(entered, suggestion$grades)) {
      return(tags$p(class = "hint", "Custom grade order. Check that every grade appears once, lowest to highest."))
    }
    if (length(suggestion$unmatched) || length(suggestion$ambiguous)) {
      return(div(class = "hint", role = "status",
        tags$p("An order could not be inferred for all grades. Labels are listed as they first appear in the file; check and edit the order."),
        if (length(suggestion$unmatched)) {
          tags$p(paste("Unrecognized labels:", paste(suggestion$unmatched, collapse = ", ")))
        },
        if (length(suggestion$ambiguous)) {
          tags$p(paste("Labels that map to the same grade:",
            paste(suggestion$ambiguous, collapse = ", ")))
        }
      ))
    }
    tags$p(class = "hint", "Suggested from your data. Check the order or edit it. Original grade labels are preserved.")
  })
  settings <- reactive({
    state <- history_state()
    if (!is.null(state$error)) {
      stop(state$error, call. = FALSE)
    }
    history <- state$data
    grades <- trimws(strsplit(input$grades, ",", fixed = TRUE)[[1]])
    year <- if (input$base_mode == "latest") {
      max(history$year)
    } else {
      input$base_year
    }
    base <- if (input$base_mode == "latest") {
      history[history$year == year, ]
    } else {
      validate_table(upload(input$base_file), "base")
    }
    horizon <- input$horizon
    if (
      is.null(horizon) ||
        !is.finite(horizon) ||
        horizon < 1 ||
        horizon > 30 ||
        horizon != floor(horizon)
    ) {
      stop(
        "Enter a projection period from 1 to 30 years, using a whole number.",
        call. = FALSE
      )
    }
    if (is.null(year) || !is.finite(year)) {
      stop("Choose a base year.", call. = FALSE)
    }
    list(
      history = history,
      base = base,
      grades = grades,
      year = year,
      horizon = horizon
    )
  })
  output$history_status <- renderUI({
    state <- history_state()
    if (!is.null(state$error)) {
      return(div(role = "alert", state$error))
    }
    div(
      class = "data-status",
      sprintf(
        "%s records, %s grades, %s to %s.",
        nrow(state$data),
        length(unique(state$data$grade)),
        min(state$data$year),
        max(state$data$year)
      )
    )
  })
  output$history_preview <- renderTable({
    req(history_state()$data)
    head(history_state()$data, 20)
  })
  output$entry_context <- renderUI({
    tryCatch(
      {
        s <- settings()
        period <- if (s$horizon == 1) {
          sprintf("Projected year: %s", s$year + 1)
        } else {
          sprintf("Projected years: %s to %s",
            s$year + 1, s$year + s$horizon)
        }
        tags$p(sprintf(
          "Entry grade: %s. %s. Base year: %s.",
          s$grades[1],
          period,
          s$year
        ))
      },
      error = function(e) div(role = "alert", conditionMessage(e))
    )
  })
  # Keep existing input nodes: replacing the whole form can discard edits in flight.
  entry_years <- integer()
  observe({
    s <- tryCatch(settings(), error = function(e) NULL)
    if (is.null(s)) return()
    if (s$year != floor(s$year) || s$year < 1900 ||
      s$year + s$horizon > 9999) return()
    years <- s$year + seq_len(s$horizon)
    for (year in setdiff(entry_years, years)) {
      removeUI(paste0("#entry_field_", year), immediate = TRUE)
    }
    retained <- intersect(entry_years, years)
    for (year in setdiff(years, retained)) {
      id <- paste0("entry_", year)
      value <- isolate(input[[id]])
      if (is.null(value)) {
        value <- s$base$enrollment[match(s$grades[1], s$base$grade)]
      }
      following <- retained[retained > year]
      insertUI(
        selector = if (length(following)) {
          paste0("#entry_field_", min(following))
        } else "#entry_fields",
        where = if (length(following)) "beforeBegin" else "beforeEnd",
        ui = div(id = paste0("entry_field_", year),
          numericInput(id, paste("Enrollment in", year), value, min = 0)),
        immediate = TRUE
      )
      retained <- c(retained, year)
    }
    entry_years <<- years
  }, priority = 110)
  result <- reactive({
    warnings <- character()
    tryCatch(
      withCallingHandlers(
        {
          s <- settings()
          entry <- switch(
            input$entry_mode,
            constant = rep(
              s$base$enrollment[match(s$grades[1], s$base$grade)],
              s$horizon
            ),
            manual = vapply(
              s$year + seq_len(s$horizon),
              function(year) {
                value <- input[[paste0("entry_", year)]]
                if (is.null(value)) NA_real_ else value
              },
              numeric(1)
            ),
            upload = align_entry(upload(input$entry_file), s$year, s$horizon)
          )
          data <- build_projection(
            s$history,
            s$base,
            s$grades,
            s$year,
            s$horizon,
            entry,
            input$method
          )
          list(data = data, warnings = warnings)
        },
        warning = function(w) {
          warnings <<- c(warnings, conditionMessage(w))
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) list(error = conditionMessage(e))
    )
  })
  projection <- reactive({
    validate(need(is.null(result()$error), result()$error))
    result()$data
  })
  output$projection_ready <- renderText({
    if (is.null(result()$error)) "ready" else "invalid"
  })
  outputOptions(output, "projection_ready", suspendWhenHidden = FALSE)
  # Calculate before outputs run, avoiding a deep render-time stack in webR.
  observeEvent(projection(), {
    grades <- projection()$grades
    selected <- isolate(input$view_grade)
    choices <- c(
      "Total enrollment" = "__total__",
      stats::setNames(grades, grades)
    )
    if (!selected %in% choices) {
      selected <- "__total__"
    }
    updateSelectInput(
      session,
      "view_grade",
      choices = choices,
      selected = selected
    )
  }, priority = 100)
  output$result_status <- renderUI({
    r <- result()
    if (!is.null(r$error)) {
      return(div(class = "notice notice-error", role = "alert",
        tags$strong("Check your inputs"), tags$p(r$error)))
    }
    div(
      class = "result-status",
      role = "status",
      tags$p(class = "source-status",
        tags$span(class = "status-label",
          if (input$source == "example") "Example data" else "Uploaded data"),
        " Results update automatically."),
      tags$p(class = "hint", sprintf("%s ratios. %s",
        switch(input$method, mean = "Mean", median = "Median",
          geometric = "Geometric mean", last = "Most recent transition"),
        switch(input$entry_mode,
          constant = "Entry enrollment held at the base-year count.",
          manual = "Entry enrollment entered for each projected year.",
          upload = "Entry enrollment supplied from your file."))),
      if (length(r$warnings)) {
        div(class = "notice", paste(r$warnings, collapse = " "))
      }
    )
  })
  output$summary <- renderUI({
    p <- projection()
    total <- sum(p$base$enrollment)
    final <- sum(p$projection$enrollment[
      p$projection$year == max(p$projection$year)
    ])
    tags$dl(class = "projection-summary",
      div(class = "metric",
        tags$dt(paste("Base enrollment", unique(p$base$year))),
        tags$dd(format(round(total), big.mark = ","))),
      div(class = "metric metric-primary",
        tags$dt(paste("Projected enrollment", max(p$projection$year))),
        tags$dd(format(round(final), big.mark = ","))),
      div(class = "metric",
        tags$dt("Change from base"),
        tags$dd(sprintf("%+.0f", final - total)))
    )
  })
  # A direct image renderer avoids renderPlot's deeper call stack in webR/Safari.
  output$projection_plot <- renderImage(
    {
      p <- projection()
      summarize <- function(data) {
        if (input$view_grade == "__total__") {
          aggregate(enrollment ~ year, data, sum)
        } else {
          data[data$grade == input$view_grade, c("year", "enrollment")]
        }
      }
      history <- summarize(p$history)
      base <- summarize(p$base)
      future <- rbind(base, summarize(p$projection))
      plot <- ggplot() +
        geom_line(
          data = history,
          aes(year, enrollment, color = "Observed"),
          linewidth = 1
        ) +
        geom_point(
          data = history,
          aes(year, enrollment, color = "Observed"),
          size = 2
        ) +
        geom_line(
          data = future,
          aes(year, enrollment, color = "Projected"),
          linetype = "dashed",
          linewidth = 1
        ) +
        geom_point(
          data = base,
          aes(year, enrollment),
          shape = 23,
          fill = "#bf7338",
          size = 3
        ) +
        scale_color_manual(
          values = c(Observed = "#17665b", Projected = "#a45c2c")
        ) +
        scale_x_continuous(
          breaks = function(limits) {
            years <- pretty(limits, n = 8)
            years[years == floor(years)]
          }
        ) +
        labs(
          title = if (nzchar(trimws(input$school))) input$school else NULL,
          x = "Year",
          y = "Enrollment",
          color = NULL
        ) +
        theme_minimal(base_size = 13) +
        theme(legend.position = "top", panel.grid.minor = element_blank())
      width <- session$clientData$output_projection_plot_width
      if (is.null(width)) width <- 600
      pixelratio <- session$clientData$pixelratio
      if (is.null(pixelratio)) pixelratio <- 1
      req(is.finite(width), width > 0, is.finite(pixelratio), pixelratio > 0)
      path <- tempfile(fileext = ".png")
      complete <- FALSE
      device <- NULL
      on.exit({
        if (!is.null(device)) grDevices::dev.off(device)
        if (!complete) unlink(path)
      })
      grDevices::png(path, width = width * pixelratio,
        height = 360 * pixelratio, res = 72 * pixelratio)
      device <- grDevices::dev.cur()
      print(plot)
      grDevices::dev.off(device)
      device <- NULL
      complete <- TRUE
      list(src = path, contentType = "image/png", width = width, height = 360,
        alt = "Enrollment by year. The solid line shows historical enrollment, a diamond marks base enrollment, and the dashed line shows projected enrollment. Rounded projected counts by grade and year are provided in the following table; unrounded values are available in the CSV download.")
    },
    deleteFile = TRUE
  )
  output$projection_table <- renderTable({
    p <- projection()$projection
    p$enrollment <- round(p$enrollment)
    p
  })
  output$ratios_table <- renderTable(projection()$ratios, digits = 4)
  output$history_template <- downloadHandler(
    "history-template.csv",
    function(file) {
      write.csv(example_history(), file, row.names = FALSE)
    }
  )
  output$base_template <- downloadHandler("base-template.csv", function(file) {
    write.csv(subset(example_history(), year == 2023), file, row.names = FALSE)
  })
  output$entry_template <- downloadHandler(
    "entry-template.csv",
    function(file) {
      s <- settings()
      write.csv(
        data.frame(
          year = s$year + seq_len(s$horizon),
          enrollment = rep(
            s$base$enrollment[match(s$grades[1], s$base$grade)],
            s$horizon
          )
        ),
        file,
        row.names = FALSE
      )
    }
  )
  output$projection_download <- downloadHandler(
    "enrollment-projection.csv",
    function(file) {
      write.csv(projection()$projection, file, row.names = FALSE)
    }
  )
  output$ratios_download <- downloadHandler(
    "progression-ratios.csv",
    function(file) {
      write.csv(projection()$ratios, file, row.names = FALSE)
    }
  )
}
