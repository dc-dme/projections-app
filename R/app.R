library(shiny)
library(bslib)
library(ggplot2)

ui <- page_sidebar(
  title = "Enrollment Projections Calculator",
  theme = bs_theme(
    version = 5,
    bg = "#f5f4ef",
    fg = "#203b3b",
    primary = "#17665b",
    base_font = "system-ui"
  ),
  fillable = FALSE,
  sidebar = sidebar(
    width = 320,
    tags$p(class = "eyebrow", "Projections Workspace"),
    textInput("school", "School or LEA name", "Example district"),
    helpText("LEA: local education agency."),
    radioButtons(
      "source",
      "Enrollment data",
      c("Use example data" = "example", "Upload enrollment data" = "upload")
    ),
    tags$hr(),
    numericInput(
      "horizon",
      "Projection period (years)",
      5,
      min = 1,
      max = 30,
      step = 1
    ),
    selectInput(
      "method",
      "Grade progression ratio method",
      c(
        "Average (mean)" = "mean",
        "Median" = "median",
        "Geometric mean" = "geometric",
        "Most recent transition" = "last"
      )
    ),
    helpText(
      "Grade progression ratios measure changes in cohort enrollment between consecutive grades and years. Methods use all available consecutive-year transitions, except the most recent transition method."
    ),
    tags$hr(),
    tags$p(
      "For planning use only. These projections assume historical progression patterns continue; they do not include uncertainty intervals."
    ),
    tags$small(
      "Upload aggregate enrollment counts only. Do not upload student-level records or other personally identifiable information (PII)."
    )
  ),
  tags$head(tags$link(rel = "stylesheet", href = "app.css")),
  if (grepl("emscripten", R.version$platform)) {
    tags$head(tags$script(src = "browser-downloads.js"))
  },
  tags$div(
    class = "intro",
    tags$h1("Calculate enrollment projections."),
    tags$p(
      "Use historical enrollment, base-year enrollment, and entry enrollment assumptions to project enrollment by grade."
    )
  ),
  navset_card_underline(
    id = "step",
    nav_panel(
      "1. Review enrollment data",
      value = "data",
      tags$h2("Historical and base enrollment"),
      tags$p(
        "Prepare data for one school, LEA or school district. Use the same reporting unit across all files. Templates contain illustrative kindergarten through grade 2 (K-2) data; replace all example rows with the applicable grades and enrollment counts."
      ),
      layout_columns(
        div(
          tags$h3("Historical enrollment"),
          tags$p("Columns: year, grade, enrollment."),
          tags$p(
            "Include one row per grade per year and at least two consecutive years of enrollment data."
          ),
          downloadButton("history_template", "Download history template"),
          conditionalPanel(
            "input.source === 'upload'",
            fileInput(
              "history_file",
              "Upload historical enrollment",
              accept = c(".csv", ".xlsx", ".xls")
            )
          )
        ),
        div(
          tags$h3("Base enrollment"),
          tags$p(
            "Base enrollment provides the starting count for each grade, usually from the most recently observed year."
          ),
          radioButtons(
            "base_mode",
            "Base enrollment source",
            c(
              "Most recent historical year" = "latest",
              "Upload a separate file" = "upload"
            )
          ),
          conditionalPanel(
            "input.base_mode === 'upload'",
            fileInput(
              "base_file",
              "Upload base enrollment",
              accept = c(".csv", ".xlsx", ".xls")
            ),
            numericInput("base_year", "Base year", 2023, min = 1900, max = 9998)
          ),
          tags$p(
            "Columns: grade, enrollment; optional year must match the base year."
          ),
          downloadButton("base_template", "Download base template")
        ),
        col_widths = c(6, 6)
      ),
      tags$hr(),
      tags$p("CSV: comma-separated, with column headings."),
      tags$p(
        "Excel: only the first worksheet is read. Column headings are case-insensitive for both file formats."
      ),
      tags$p(
        "Identify each school year with a single four-digit year, such as 2023 for 2023-24. Use the same convention across all files."
      ),
      tags$p(
        "Enrollment counts are required. Enter 0 only where enrollment is known to be zero; blank values are not treated as zero."
      ),
      textInput(
        "grades",
        "Grade order, lowest to highest (comma-separated)",
        "K, 1, 2"
      ),
      helpText(
        "Include every grade exactly once. The first grade is the entry grade. Example: For K-12, enter K, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12."
      ),
      uiOutput("history_status"),
      div(class = "table-scroll", tableOutput("history_preview"))
    ),
    nav_panel(
      "2. Define entry enrollment",
      value = "entry",
      tags$h2("Entry enrollment assumptions"),
      tags$p(
        "Entry enrollment supplies future cohorts for the lowest grade in the selected grade order. These cohorts are not present in the base enrollment and must be specified separately."
      ),
      uiOutput("entry_context"),
      radioButtons(
        "entry_mode",
        "Entry enrollment source",
        c(
          "Hold constant at base-year entry enrollment" = "constant",
          "Enter enrollment for each projected year" = "manual",
          "Upload entry enrollment" = "upload"
        )
      ),
      conditionalPanel(
        "input.entry_mode === 'manual'",
        uiOutput("entry_fields")
      ),
      conditionalPanel(
        "input.entry_mode === 'upload'",
        tags$p(
          "Columns: year, enrollment. Include one row for each projected year and no additional years. Rows may appear in any order."
        ),
        downloadButton("entry_template", "Download entry template"),
        fileInput(
          "entry_file",
          "Upload entry enrollment",
          accept = c(".csv", ".xlsx", ".xls")
        )
      ),
      tags$p(
        "Entry enrollment is a user-specified assumption, not an estimate produced by this calculator. Consider birth cohorts, lottery seats, housing changes, and other local factors when developing these assumptions."
      )
    ),
    nav_panel(
      "3. Review projections",
      value = "results",
      uiOutput("result_status"),
      uiOutput("summary"),
      selectInput(
        "view_grade",
        "Enrollment displayed in chart",
        c("Total enrollment" = "__total__")
      ),
      plotOutput("projection_plot", height = "360px"),
      tags$p(class = "text-muted",
        "Diamond: base enrollment. Dashed line: projected enrollment. Uncertainty intervals are not shown."),
      downloadButton("projection_download", "Download projections (CSV)"),
      downloadButton("ratios_download", "Download ratios (CSV)"),
      tags$h3("Projected enrollment"),
      tags$p(
        "Enrollment counts in the table are rounded to the nearest student. CSV downloads retain unrounded values. Results update automatically when inputs change."
      ),
      div(class = "table-scroll", tableOutput("projection_table")),
      tags$h3("Grade progression ratios"),
      tags$p(
        "A ratio of 1 indicates no change in cohort enrollment between grades. Ratios above 1 indicate an increase; ratios below 1 indicate a decrease."
      ),
      tableOutput("ratios_table")
    )
  )
)

server <- function(input, output, session) {
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
      class = "notice",
      sprintf(
        "%s records | %s grades | %s to %s. Preview shows up to 20 records.",
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
  output$entry_fields <- renderUI({
    s <- tryCatch(settings(), error = function(e) NULL)
    req(s)
    count <- s$base$enrollment[match(s$grades[1], s$base$grade)]
    layout_column_wrap(
      width = "180px",
      fill = FALSE,
      !!!lapply(s$year + seq_len(s$horizon), function(year) {
        id <- paste0("entry_", year)
        value <- isolate(input[[id]])
        if (is.null(value)) {
          value <- count
        }
        numericInput(id, paste("Enrollment in", year), value, min = 0)
      })
    )
  })
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
  })
  output$result_status <- renderUI({
    r <- result()
    if (!is.null(r$error)) {
      return(div(class = "notice", role = "alert", r$error))
    }
    div(
      class = "notice",
      role = "status",
      if (input$source == "example") {
        "Data source: illustrative example. "
      } else {
        "Data source: uploaded enrollment records. "
      },
      "Projections calculated using the current inputs and assumptions. ",
      paste(r$warnings, collapse = " ")
    )
  })
  output$summary <- renderUI({
    p <- projection()
    total <- sum(p$base$enrollment)
    final <- sum(p$projection$enrollment[
      p$projection$year == max(p$projection$year)
    ])
    layout_column_wrap(
      width = "200px",
      fill = FALSE,
      value_box("Base enrollment", format(round(total), big.mark = ",")),
      value_box(
        paste("Projected enrollment in", max(p$projection$year)),
        format(round(final), big.mark = ",")
      ),
      value_box(
        "Change from base enrollment",
        sprintf("%+.0f students", final - total)
      )
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
          title = input$school,
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
