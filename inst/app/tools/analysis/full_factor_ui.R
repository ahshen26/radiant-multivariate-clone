ff_method <- c("Principal components" = "PCA", "Maximum Likelihood" = "maxlik")
ff_rotation <- c(
  "None" = "none", "Varimax" = "varimax", "Quartimax" = "quartimax",
  "Equamax" = "equamax", "Promax" = "promax",
  "Oblimin" = "oblimin", "Simplimax" = "simplimax"
)

## list of function arguments
ff_args <- as.list(formals(full_factor))

## list of function inputs selected by user
ff_inputs <- reactive({
  ff_args$data_filter <- if (input$show_filter) input$data_filter else ""
  ff_args$dataset <- input$dataset
  ## loop needed because reactive values don't allow single bracket indexing
  for (i in r_drop(names(ff_args))) {
    ff_args[[i]] <- input[[paste0("ff_", i)]]
  }
  ff_args
})

###############################
# Factor analysis
###############################
output$ui_ff_vars <- renderUI({
  vars <- varnames()
  toSelect <- .get_class() %in% c("numeric", "integer", "date", "factor")
  vars <- vars[toSelect]
  selectInput(
    inputId = "ff_vars", label = "Variables:", choices = vars,
    selected = state_multiple("ff_vars", vars, input$pf_vars),
    multiple = TRUE, size = min(10, length(vars)), selectize = FALSE
  )
})

output$ui_ff_store_name <- renderUI({
  req(input$dataset)
  textInput("ff_store_name", "Store factor scores:", "", placeholder = "Provide single variable name")
})

## add a spinning refresh icon if the tabel needs to be (re)calculated
run_refresh(ff_args, "ff", init = "vars", tabs = "tabs_full_factor", label = "Estimate model", relabel = "Re-estimate model")

output$ui_full_factor <- renderUI({
  req(input$dataset)
  tagList(
    conditionalPanel(
      condition = "input.tabs_full_factor == 'Plot'",
      wellPanel(
        checkboxGroupInput(
          "ff_plots", NULL, c("Respondents" = "resp", "Attributes" = "attr"),
          selected = state_group("ff_plots", "attr"),
          inline = TRUE
        )
        # conditionalPanel(
        #   condition = "input.tabs_full_factor == 'Plot'",
        #   tags$table(
        #     tags$td(numericInput("ff_scaling", "Respondent scale:", state_init("ff_scaling", 0.5), .5, 4, .1, width = "117px")),
        #     tags$td(numericInput("ff_fontsz", "Font size:", state_init("ff_fontsz", 5), 1, 20, 1, width = "117px")),
        #     width = "100%"
        #   )
        # )
      )
    ),
    conditionalPanel(
      condition = "input.tabs_full_factor == 'Summary'",
      wellPanel(
        actionButton("ff_run", "Estimate model", width = "100%", icon = icon("play", verify_fa = FALSE), class = "btn-success")
      ),
      wellPanel(
        uiOutput("ui_ff_vars"),
        selectInput(
          "ff_method",
          label = "Method:", choices = ff_method,
          selected = state_single("ff_method", ff_method, "PCA")
        ),
        checkboxInput("ff_hcor", "Adjust for {factor} variables", value = state_init("ff_hcor", FALSE)),
        tags$table(
          tags$td(numericInput("ff_nr_fact", label = "Nr. of factors:", min = 1, value = state_init("ff_nr_fact", 1))),
          tags$td(numericInput("ff_cutoff", label = "Cutt-off:", min = 0, max = 1, value = state_init("ff_cutoff", 0), step = .05, width = "117px"))
        ),
        checkboxInput("ff_fsort", "Sort factor loadings", value = state_init("ff_fsort", FALSE)),
        selectInput(
          "ff_rotation",
          label = "rotation:", ff_rotation,
          selected = state_single("ff_rotation", ff_rotation, "varimax")
        ),
        conditionalPanel(
          condition = "input.ff_vars != null",
          tags$table(
            # tags$td(textInput("ff_store_name", "Store scores:", state_init("ff_store_name", "factor"))),
            tags$td(uiOutput("ui_ff_store_name")),
            tags$td(actionButton("ff_store", "Store", icon = icon("plus", verify_fa = FALSE)), class = "top")
          )
        )
      )
    ),
    help_and_report(
      modal_title = "Factor",
      fun_name = "full_factor",
      help_file = inclMD(file.path(getOption("radiant.path.multivariate"), "app/tools/help/full_factor.md"))
    )
  )
})

ff_plot <- reactive({
  if (pressed(input$ff_run) && length(input$ff_vars) > 1 &&
    isolate(input$ff_nr_fact) > 1) {
    plot_height <- plot_width <- 350
    nrFact <- min(isolate(input$ff_nr_fact), length(input$ff_vars))
    nrPlots <- (nrFact * (nrFact - 1)) / 2

    if (nrPlots > 2) {
      plot_height <- 350 * ceiling(nrPlots / 2)
    }

    if (nrPlots > 1) {
      plot_width <- 700
    }
  } else {
    plot_height <- plot_width <- 700
  }
  list(plot_width = plot_width, plot_height = plot_height)
})

ff_plot_width <- function() {
  ff_plot() %>%
    {
      if (is.list(.)) .$plot_width else 650
    }
}

ff_plot_height <- function() {
  ff_plot() %>%
    {
      if (is.list(.)) .$plot_height else 400
    }
}

output$full_factor <- renderUI({
  register_print_output("summary_full_factor", ".summary_full_factor")
  register_plot_output(
    "plot_full_factor", ".plot_full_factor",
    width_fun = "ff_plot_width",
    height_fun = "ff_plot_height"
  )

  ff_output_panels <- tabsetPanel(
    id = "tabs_full_factor",
    tabPanel(
      "Summary",
      download_link("dl_ff_loadings"), br(),
      verbatimTextOutput("summary_full_factor")
    ),
    tabPanel(
      "Plot",
      download_link("dlp_full_factor"),
      plotOutput("plot_full_factor", height = "100%")
    )
  )

  stat_tab_panel(
    menu = "Multivariate > Factor",
    tool = "Factor",
    tool_ui = "ui_full_factor",
    output_panels = ff_output_panels
  )
})

.ff_available <- reactive({
  if (not_pressed(input$ff_run)) {
    "** Press the Estimate button to generate factor analysis results **"
  } else if (not_available(input$ff_vars)) {
    "This analysis requires multiple variables of type numeric or integer.\nIf these variables are not available please select another dataset.\n\n" %>%
      suggest_data("toothpaste")
  } else if (length(input$ff_vars) < 2) {
    "Please select two or more variables"
  } else {
    "available"
  }
})

.full_factor <- eventReactive(input$ff_run, {
  withProgress(message = "Estimating factor solution", value = 1, {
    ffi <- ff_inputs()
    ffi$envir <- r_data
    do.call(full_factor, ffi)
  })
})

.summary_full_factor <- eventReactive(
  {
    c(input$ff_run, input$ff_cutoff, input$ff_fsort)
  },
  {
    if (not_pressed(input$ff_run)) {
      return("** Press the Estimate button to generate factor analysis results **")
    }
    if (.ff_available() != "available") {
      return(.ff_available())
    }
    if (is_not(input$ff_nr_fact)) {
      return("Number of factors should be >= 1")
    }
    validate(
      need(
        input$ff_cutoff >= 0 && input$ff_cutoff <= 1,
        "Provide a correlation cutoff value in the range from 0 to 1"
      )
    )
    summary(.full_factor(), cutoff = input$ff_cutoff, fsort = input$ff_fsort)
  }
)

.plot_full_factor <- eventReactive(
  {
    c(input$ff_run, !is.null(input$ff_plots))
  },
  {
    if (not_pressed(input$ff_run)) {
      "** Press the Estimate button to generate factor analysis results **"
    } else if (.ff_available() != "available") {
      .ff_available()
    } else if (is_not(input$ff_nr_fact) || input$ff_nr_fact < 2) {
      "Plot requires 2 or more factors.\nChange the number of factors in the Summary tab and re-estimate"
    } else {
      withProgress(message = "Generating factor plots", value = 1, {
        plot(.full_factor(), plots = input$ff_plots, shiny = TRUE)
      })
    }
  }
)

full_factor_report <- function() {
  outputs <- c("summary", "plot")
  inp_out <- list(list(cutoff = input$ff_cutoff, fsort = input$ff_fsort, dec = 2), list(custom = FALSE))
  if (!is.empty(input$ff_store_name)) {
    fixed <- fix_names(input$ff_store_name)
    updateTextInput(session, "ff_store_name", value = fixed)
    xcmd <- glue('{input$dataset} <- store({input$dataset}, result, name = "{fixed}")')
  } else {
    xcmd <- ""
  }

  # xcmd <- paste0(xcmd, "# clean_loadings(result$floadings, cutoff = ", input$ff_cutoff, ", fsort = ", input$ff_fsort, ", dec = 8) %>%\n#  write.csv(file = \"~/loadings.csv\")")
  # xcmd <- paste0("# store(result, name = \"", input$ff_store_name, "\")\n# clean_loadings(result$floadings, cutoff = ", input$ff_cutoff, ", fsort = ", input$ff_fsort, ", dec = 8) %>% write.csv(file = \"~/loadings.csv\")")

  update_report(
    inp_main = clean_args(ff_inputs(), ff_args),
    fun_name = "full_factor",
    inp_out = inp_out,
    fig.width = ff_plot_width(),
    fig.height = ff_plot_height(),
    xcmd = xcmd
  )
}

## store factor scores
observeEvent(input$ff_store, {
  req(input$ff_store_name, input$ff_run)
  fixed <- fix_names(input$ff_store_name)
  updateTextInput(session, "ff_store_name", value = fixed)
  robj <- .full_factor()
  if (!is.character(robj)) {
    withProgress(
      message = "Storing factor scores", value = 1,
      r_data[[input$dataset]] <- store(r_data[[input$dataset]], robj, name = fixed)
    )
  }
})

dl_ff_loadings <- function(path) {
  if (pressed(input$ff_run)) {
    .full_factor() %>%
      {
        if (is.list(.)) .$floadings else return()
      } %>%
      clean_loadings(input$ff_cutoff, input$ff_fsort) %>%
      write.csv(file = path)
  } else {
    cat("No output available. Press the Estimate button to generate factor loadings", file = path)
  }
}

download_handler(
  id = "dl_ff_loadings",
  fun = dl_ff_loadings,
  fn = function() paste0(input$dataset, "_loadings"),
  type = "csv",
  caption = "Save factor loadings"
)

download_handler(
  id = "dlp_full_factor",
  fun = download_handler_plot,
  fn = function() paste0(input$dataset, "_factor"),
  type = "png",
  caption = "Save factor plots",
  plot = .plot_full_factor,
  width = ff_plot_width,
  height = ff_plot_height
)

observeEvent(input$full_factor_report, {
  r_info[["latest_screenshot"]] <- NULL
  full_factor_report()
})

observeEvent(input$full_factor_screenshot, {
  r_info[["latest_screenshot"]] <- NULL
  radiant_screenshot_modal("modal_full_factor_screenshot")
})

observeEvent(input$modal_full_factor_screenshot, {
  full_factor_report()
  removeModal() ## remove shiny modal after save
})
