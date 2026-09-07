source("R/model.R", local = TRUE)
source("R/app.R", local = TRUE)
if (grepl("emscripten", R.version$platform)) {
  # Resolve the static UI outside the HTTP handler's deeper WebAssembly stack.
  shiny::shinyOptions(bootstrapTheme = attr(ui, "bs_theme"))
  rendered_ui <- htmltools::renderTags(ui)
  ui <- htmltools::attachDependencies(
    htmltools::tagList(
      tags$head(htmltools::HTML(rendered_ui$head)),
      htmltools::HTML(rendered_ui$html)
    ),
    rendered_ui$dependencies
  )
}
shinyApp(ui, server)
