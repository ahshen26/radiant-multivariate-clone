###############################
# Multidimensional scaling
###############################
mds_nr_dim <- c("2 dimensions" = 2, "3 dimensions" = 3)
mds_method <- c("metric" = "metric", "non-metric" = "non-metric")

## list of function arguments
mds_args <- as.list(formals(mds))

## list of function inputs selected by user
mds_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  mds_args$data_filter <- if (input$show_filter) input$data_filter else ""
  mds_args$dataset <- input$dataset
  for (i in r_drop(names(mds_args))) {
    mds_args[[i]] <- input[[paste0("mds_", i)]]
  }
  mds_args
})

mds_plot_args <- as.list(if (exists("plot.mds")) {
  formals(plot.mds)
} else {
  formals(radiant.multivariate:::plot.mds)
})

## list of function inputs selected by user
mds_plot_inputs <- reactive({
  ## loop needed because reactive values don't allow single bracket indexing
  for (i in names(mds_plot_args)) {
    mds_plot_args[[i]] <- input[[paste0("mds_", i)]]
  }
  mds_plot_args
})

output$ui_mds_id1 <- renderUI({
  isLabel <- "character" == .get_class() | "factor" == .get_class()
  vars <- varnames()[isLabel]
  selectInput(
    inputId = "mds_id1", label = "ID 1:", choices = vars,
    selected = state_single("mds_id1", vars), multiple = FALSE
  )
})

output$ui_mds_id2 <- renderUI({
  isLabel <- "character" == .get_class() | "factor" == .get_class()
  vars <- varnames()[isLabel]
  if (length(vars) > 0) vars <- vars[-which(vars == input$mds_id1)]
  selectInput(
    inputId = "mds_id2", label = "ID 2:", choices = vars,
    selected = state_single("mds_id2", vars), multiple = FALSE
  )
})

output$ui_mds_dis <- renderUI({
  isNum <- "numeric" == .get_class() | "integer" == .get_class()
  vars <- varnames()[isNum]
  selectInput(
    inputId = "mds_dis", label = "Dissimilarity:", choices = vars,
    selected = state_single("mds_dis", vars), multiple = FALSE
  )
})

output$ui_mds_rev_dim <- renderUI({
  # req(input$mds_nr_dim, input$mds_fontsz)
  rev_list <- list()
  # nr_dim <- ncol(.get_data())
  rev_list[paste("dimension", 1:input$mds_nr_dim)] <- 1:input$mds_nr_dim
  checkboxGroupInput(
    "mds_rev_dim", "Reverse:", rev_list,
    selected = state_group("mds_rev_dim", ""),
    inline = TRUE
  )
})

## add a spinning refresh icon if the map needs to be (re)created
run_refresh(mds_args, "mds", init = "id1", tabs = "tabs_mds", label = "Estimate model", relabel = "Re-estimate model")

output$ui_mds <- renderUI({
  req(input$dataset)
  tagList(
    conditionalPanel(
      condition = "input.tabs_mds == 'Summary'",
      wellPanel(
        actionButton("mds_run", "Estimate model", width = "100%", icon = icon("play", verify_fa = FALSE), class = "btn-success")
      )
    ),
    wellPanel(
      conditionalPanel(
        condition = "input.tabs_mds == 'Summary'",
        uiOutput("ui_mds_id1"),
        uiOutput("ui_mds_id2"),
        uiOutput("ui_mds_dis"),
        radioButtons(
          inputId = "mds_method", label = NULL, mds_method,
          selected = state_init("mds_method", "metric"),
          inline = TRUE
        ),
        radioButtons(
          inputId = "mds_nr_dim", label = NULL, mds_nr_dim,
          selected = state_init("mds_nr_dim", 2),
          inline = TRUE
        )
      ),
      conditionalPanel(
        condition = "input.tabs_mds == 'Plot'",
        numericInput("mds_fontsz", "Font size:", state_init("mds_fontsz", 5), 1, 30, 1),
        uiOutput("ui_mds_rev_dim")
      )
    ),
    help_and_report(
      modal_title = "(Dis)similarity based brand maps (MDS)",
      fun_name = "mds",
      help_file = inclMD(file.path(getOption("radiant.path.multivariate"), "app/tools/help/mds.md"))
    )
  )
})

mds_plot <- eventReactive(input$mds_run, {
  req(input$mds_nr_dim)
  nrDim <- .mds() %>%
    (function(x) if (is.list(x)) ncol(x$res$points) else as.numeric(input$mds_nr_dim))
  nrPlots <- (nrDim * (nrDim - 1)) / 2
  list(plot_width = 650, plot_height = 650 * nrPlots)
})

mds_plot_width <- function() {
  mds_plot() %>%
    (function(x) if (is.list(x)) x$plot_width else 650)
}

mds_plot_height <- function() {
  mds_plot() %>%
    (function(x) if (is.list(x)) x$plot_height else 650)
}

output$mds <- renderUI({
  register_print_output("summary_mds", ".summary_mds")
  register_plot_output(
    "plot_mds", ".plot_mds",
    width_fun = "mds_plot_width",
    height_fun = "mds_plot_height"
  )

  mds_output_panels <- tabsetPanel(
    id = "tabs_mds",
    tabPanel(
      "Summary",
      download_link("dl_mds_coord"), br(),
      verbatimTextOutput("summary_mds")
    ),
    tabPanel(
      "Plot",
      download_link("dlp_mds"),
      plotOutput("plot_mds", height = "100%")
    )
  )

  stat_tab_panel(
    menu = "Multivariate > Maps",
    tool = "(Dis)similarity",
    tool_ui = "ui_mds",
    output_panels = mds_output_panels
  )
})

.mds_available <- reactive({
  if (not_pressed(input$mds_run)) {
    "** Press the Estimate button to generate maps **"
  } else if (not_available(input$mds_id1) || not_available(input$mds_id2) || not_available(input$mds_dis)) {
    "This analysis requires two id-variables of type character or factor and a measure\nof dissimilarity of type numeric or interval. Please select another dataset\n\n" %>%
      suggest_data("city")
  } else {
    "available"
  }
})

.mds <- eventReactive(input$mds_run, {
  req(input$mds_id1)
  withProgress(message = "Generating MDS solution", value = 1, {
    mdsi <- mds_inputs()
    mdsi$envir <- r_data
    do.call(mds, mdsi)
  })
})

.summary_mds <- reactive({
  if (.mds_available() != "available") {
    return(.mds_available())
  }
  .mds() %>%
    {
      if (is.character(.)) . else summary(., dec = 2)
    }
})

.plot_mds <- reactive({
  if (.mds_available() != "available") {
    return(.mds_available())
  }
  req("mds_rev_dim" %in% names(input))
  robj <- .mds()
  if (is.character(robj)) {
    return(robj)
  }
  withProgress(message = "Generating brand maps", value = 1, {
    do.call(plot, c(list(x = robj), mds_plot_inputs(), shiny = TRUE))
  })
})

mds_report <- function() {
  outputs <- c("summary", "plot")
  inp_out <- list(list(dec = 2), "")
  inp <- mds_inputs()
  inp$nr_dim <- as.integer(inp$nr_dim)
  mpi <- mds_plot_inputs()
  if (length(mpi$rev_dim) > 0) mpi$rev_dim <- as.integer(mpi$rev_dim)
  inp_out[[2]] <- clean_args(mpi, mds_plot_args[-1])
  update_report(
    inp_main = clean_args(inp, mds_args),
    fun_name = "mds",
    inp_out = inp_out,
    fig.width = mds_plot_width(),
    fig.height = mds_plot_height()
  )
}

dl_mds_coord <- function(path) {
  if (pressed(input$mds_run)) {
    .mds()$res$points %>%
      (function(x) set_colnames(x, paste0("Dimension", 1:ncol(x)))) %>%
      write.csv(file = path, row.names = FALSE)
  } else {
    cat("No output available. Press the Estimate button to generate results", file = path)
  }
}

download_handler(
  id = "dl_mds_coord",
  fun = dl_mds_coord,
  fn = function() paste0(input$dataset, "_mds_coordinates"),
  type = "csv",
  caption = "Save MDS coordinates"
)

download_handler(
  id = "dlp_mds",
  fun = download_handler_plot,
  fn = function() paste0(input$dataset, "_mds"),
  type = "png",
  caption = "Save MDS plot",
  plot = .plot_mds,
  width = mds_plot_width,
  height = mds_plot_height
)

observeEvent(input$mds_report, {
  r_info[["latest_screenshot"]] <- NULL
  mds_report()
})

observeEvent(input$mds_screenshot, {
  r_info[["latest_screenshot"]] <- NULL
  radiant_screenshot_modal("modal_mds_screenshot")
})

observeEvent(input$modal_mds_screenshot, {
  mds_report()
  removeModal() ## remove shiny modal after save
})
