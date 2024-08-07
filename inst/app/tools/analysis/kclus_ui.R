###############################################################
# K-clustering
###############################################################

km_plots <- c("None" = "none", "Density" = "density", "Bar" = "bar", "Scatter" = "scatter", "Pairwise" = "pairwise")
km_algorithm <- c("K-means" = "kmeans", "K-proto" = "kproto")

# list of function arguments
km_args <- as.list(formals(kclus))

km_inputs <- reactive({
  # loop needed because reactive values don't allow single bracket indexing
  km_args$data_filter <- if (input$show_filter) input$data_filter else ""
  km_args$dataset <- input$dataset
  for (i in r_drop(names(km_args))) {
    km_args[[i]] <- input[[paste0("km_", i)]]
  }
  km_args
})

output$ui_km_vars <- renderUI({
  sel <- .get_class() %in% c("integer", "numeric", "factor")
  vars <- varnames()[sel]
  selectInput(
    inputId = "km_vars", label = "Variables:", choices = vars,
    selected = state_multiple("km_vars", vars, input$hc_vars),
    multiple = TRUE, size = min(8, length(vars)), selectize = FALSE
  )
})

output$ui_km_lambda <- renderUI({
  numericInput(
    "km_lambda", "Lambda:",
    min = 0,
    value = state_init("km_lambda", NA)
  )
})

observeEvent(input$km_fun, {
  if (input$km_fun == "kmeans") {
    updateNumericInput(session = session, inputId = "km_lambda", value = NA)
  }
})

observeEvent(input$dataset, {
  updateSelectInput(session = session, inputId = "km_plots", selected = "none")
})

output$ui_km_store_name <- renderUI({
  req(input$dataset)
  textInput("km_store_name", NULL, "", placeholder = "Provide variable name")
})

## add a spinning refresh icon if the table needs to be (re)calculated
run_refresh(km_args, "km", init = "vars", tabs = "tabs_kclus", label = "Estimate model", relabel = "Re-estimate model")

output$ui_kclus <- renderUI({
  req(input$dataset)
  tagList(
    conditionalPanel(
      condition = "input.tabs_kclus == 'Model Summary'",
      wellPanel(
        actionButton("km_run", "Estimate model", width = "100%", icon = icon("play", verify_fa = FALSE), class = "btn-success")
      )
    ),
    wellPanel(
      conditionalPanel(
        condition = "input.tabs_kclus == 'Model Summary'",
        selectInput(
          "km_fun",
          label = "Algorithm:", choices = km_algorithm,
          selected = state_single("km_fun", km_algorithm, "kmeans"), multiple = FALSE
        ),
        uiOutput("ui_km_vars"),
        conditionalPanel(
          condition = "input.km_fun == 'kproto'",
          uiOutput("ui_km_lambda")
        ),
        checkboxInput("km_standardize", "Standardize", state_init("km_standardize", TRUE)),
        checkboxInput(
          inputId = "km_hc_init", label = "Initial centers from HC",
          value = state_init("km_hc_init", FALSE)
        ),
        conditionalPanel(
          condition = "input.km_hc_init == true",
          wellPanel(
            selectInput(
              "km_distance",
              label = "Distance measure:", choices = hc_distance,
              selected = state_single("km_distance", hc_distance, "sq.euclidian"), multiple = FALSE
            ),
            selectInput(
              "km_method",
              label = "Method:", choices = hc_method,
              selected = state_single("km_method", hc_method, "ward.D"), multiple = FALSE
            )
          )
        ),
        conditionalPanel(
          condition = "input.km_hc_init == false",
          numericInput(
            "km_seed", "Set random seed:",
            min = 0,
            value = state_init("km_seed", 1234)
          )
        ),
        numericInput(
          "km_nr_clus", "Number of clusters:",
          min = 2,
          value = state_init("km_nr_clus", 2)
        ),
        conditionalPanel(
          condition = "input.km_vars != null",
          # HTML("<label>Store cluster membership:</label>"),
          tags$label("Store cluster membership:"),
          tags$table(
            tags$td(uiOutput("ui_km_store_name")),
            tags$td(actionButton("km_store", "Store", icon = icon("plus", verify_fa = FALSE)), class = "top_mini")
          )
        )
      ),
      conditionalPanel(
        condition = "input.tabs_kclus == 'Model Performance Plots'",
        selectInput(
          "km_plots",
          label = "Plot(s):", choices = km_plots,
          selected = state_multiple("km_plots", km_plots, "none"),
          multiple = FALSE
        )
      )
    ),
    help_and_report(
      modal_title = "K-clustering",
      fun_name = "kclus",
      help_file = inclMD(file.path(getOption("radiant.path.multivariate"), "app/tools/help/kclus.md"))
    )
  )
})

km_plot <- eventReactive(c(input$km_run, input$km_plots), {
  if (.km_available() == "available" && !is.empty(input$km_plots, "none")) {
    list(plot_width = if (input$km_plots == "pairwise") 750 else 650,
         plot_height = if (input$km_plots == "pairwise") 750 else 300 * ceiling(length(input$km_vars) / 2))
  }
})

km_plot_width <- function() {
  km_plot() %>%
    {
      if (is.list(.)) .$plot_width else 650
    }
}

km_plot_height <- function() {
  km_plot() %>%
    {
      if (is.list(.)) .$plot_height else 400
    }
}


# output is called from the main radiant ui.R
output$kclus <- renderUI({
  register_print_output("summary_kclus", ".summary_kclus")
  register_plot_output(
    "plot_kclus", ".plot_kclus",
    width_fun = "km_plot_width",
    height_fun = "km_plot_height"
  )
  
  km_output_panels <- tabsetPanel(
    id = "tabs_kclus",
    tabPanel(
      "Model Summary",
      download_link("dl_km_means"), br(),
      verbatimTextOutput("summary_kclus")
    ),
    tabPanel(
      "Model Performance Plots",
      download_link("dlp_kclus"),
      plotOutput("plot_kclus", width = "100%", height = "100%")
    )
  )
  
  stat_tab_panel(
    menu = "Multivariate > Cluster",
    tool = "K-clustering",
    tool_ui = "ui_kclus",
    output_panels = km_output_panels
  )
})

.km_available <- reactive({
  if (not_pressed(input$km_run)) {
    "** Press the Estimate button to generate the cluster solution **"
  } else if (not_available(input$km_vars)) {
    "This analysis requires one or more variables of type numeric or integer.\nIf these variable types are not available please select another dataset.\n\n" %>%
      suggest_data("toothpaste")
  } else {
    "available"
  }
})

.kclus <- eventReactive(input$km_run, {
  withProgress(message = "Estimating cluster solution", value = 1, {
    kmi <- km_inputs()
    kmi$envir <- r_data
    do.call(kclus, kmi)
  })
})

.summary_kclus <- reactive({
  if (.km_available() != "available") {
    return(.km_available())
  }
  summary(.kclus())
})

.plot_kclus <- eventReactive(c(input$km_run, input$km_plots), {
  if (.km_available() != "available") {
    .km_available()
  } else if (is.empty(input$km_plots, "none")) {
    "Please select a plot type from the drop-down menu"
  } else {
    withProgress(message = "Generating plots", value = 1, {
      plot(.kclus(), plots = input$km_plots, shiny = TRUE)
    })
  }
})

kclus_report <- function() {
  inp_out <- list(list(dec = 2), "")
  if (!is.empty(input$km_plots, "none")) {
    figs <- TRUE
    outputs <- c("summary", "plot")
    inp_out[[2]] <- list(plots = input$km_plots, custom = FALSE)
  } else {
    outputs <- c("summary")
    figs <- FALSE
  }
  
  if (!is.empty(input$km_store_name)) {
    fixed <- fix_names(input$km_store_name)
    updateTextInput(session, "km_store_name", value = fixed)
    xcmd <- glue('{input$dataset} <- store({input$dataset}, result, name = "{fixed}")')
  } else {
    xcmd <- ""
  }
  
  kmi <- km_inputs()
  if (input$km_fun == "kmeans") kmi$lambda <- NULL
  
  update_report(
    inp_main = clean_args(kmi, km_args),
    fun_name = "kclus",
    inp_out = inp_out,
    outputs = outputs,
    figs = figs,
    fig.width = km_plot_width(),
    fig.height = km_plot_height(),
    xcmd = xcmd
  )
}

## store cluster membership
observeEvent(input$km_store, {
  req(input$km_store_name, input$km_run)
  fixed <- fix_names(input$km_store_name)
  updateTextInput(session, "km_store_name", value = fixed)
  robj <- .kclus()
  if (!is.character(robj)) {
    withProgress(
      message = "Storing cluster membership", value = 1,
      r_data[[input$dataset]] <- store(r_data[[input$dataset]], robj, name = fixed)
    )
  }
})

dl_km_means <- function(path) {
  if (pressed(input$km_run)) {
    .kclus() %>%
      {
        if (is.list(.)) write.csv(.$clus_means, file = path)
      }
  } else {
    cat("No output available. Press the Estimate button to generate the cluster solution", file = path)
  }
}

download_handler(
  id = "dl_km_means",
  fun = dl_km_means,
  fn = function() paste0(input$dataset, "_kclus"),
  type = "csv",
  caption = "Save clustering results "
)

download_handler(
  id = "dlp_kclus",
  fun = download_handler_plot,
  fn = function() paste0(input$dataset, "_kclustering"),
  type = "png",
  caption = "Save k-cluster plots",
  plot = .plot_kclus,
  width = km_plot_width,
  height = km_plot_height
)

observeEvent(input$kclus_report, {
  r_info[["latest_screenshot"]] <- NULL
  kclus_report()
})

observeEvent(input$kclus_screenshot, {
  r_info[["latest_screenshot"]] <- NULL
  radiant_screenshot_modal("modal_kclus_screenshot")
})

observeEvent(input$modal_kclus_screenshot, {
  kclus_report()
  removeModal() ## remove shiny modal after save
})
