## urls for menu
r_url_list <- getOption("radiant.url.list")
r_url_list[["Hierarchical clustering"]] <- "multivariate/hclus/"
r_url_list[["K-clustering"]] <-
  list("tabs_kclus" = list("Summary" = "multivariate/kclus/", "Plot" = "multivariate/kclus/plot/"))

options(radiant.url.list = r_url_list)
rm(r_url_list)

## design menu
options(
  radiant.multivariate_ui =
    tagList(
      navbarMenu(
        "Multivariate",
        tags$head(
          tags$script(src = "www_multivariate/js/store.js")
        ),
        "----", "Cluster",
        tabPanel("Hierarchical", uiOutput("hclus")),
        tabPanel("K-clustering", uiOutput("kclus"))
      )
    )
)

