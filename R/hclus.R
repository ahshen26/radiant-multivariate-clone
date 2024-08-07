#' Hierarchical cluster analysis
#'
#' @details See \url{https://radiant-rstats.github.io/docs/multivariate/hclus.html} for an example in Radiant
#'
#' @param dataset Dataset
#' @param vars Vector of variables to include in the analysis
#' @param labels A vector of labels for the leaves of the tree
#' @param distance Distance
#' @param method Method
#' @param max_cases Maximum number of cases allowed (default is 1000). Set to avoid long-running analysis in the radiant web-interface
#' @param standardize Standardized data (TRUE or FALSE)
#' @param data_filter Expression entered in, e.g., Data > View to filter the dataset in Radiant. The expression should be a string (e.g., "price > 10000")
#' @param envir Environment to extract data from
#'
#' @return A list of all variables used in hclus as an object of class hclus
#'
#' @examples
#' hclus(shopping, vars = "v1:v6") %>% str()
#'
#' @seealso \code{\link{summary.hclus}} to summarize results
#' @seealso \code{\link{plot.hclus}} to plot results
#'
#' @importFrom gower gower_dist
#'
#' @export
hclus <- function(dataset, vars, labels = "none", distance = "sq.euclidian",
                  method = "ward.D", max_cases = 5000,
                  standardize = TRUE, data_filter = "",
                  envir = parent.frame()) {
  df_name <- if (is_string(dataset)) dataset else deparse(substitute(dataset))
  dataset <- get_data(dataset, if (labels == "none") vars else c(labels, vars), filt = data_filter, envir = envir) %>%
    as.data.frame() %>%
    mutate_if(is.Date, as.numeric)
  rm(envir)
  if (nrow(dataset) > max_cases) {
    return("The number of cases to cluster exceed the maximum set. Change\nthe number of cases allowed using the 'Max cases' input box." %>%
      add_class("hclus"))
  }

  anyCategorical <- sapply(dataset, function(x) is.numeric(x)) == FALSE
  ## in case : is used
  if (length(vars) < ncol(dataset)) vars <- colnames(dataset)
  if (any(anyCategorical) && distance != "gower") distance <- "gower"

  if (labels != "none") {
    if (length(unique(dataset[[1]])) == nrow(dataset)) {
      rownames(dataset) <- dataset[[1]]
    } else {
      message("\nThe provided labels are not unique. Please select another labels variable\n")
      rownames(dataset) <- seq_len(nrow(dataset))
    }
    dataset <- select(dataset, -1)
  }

  if (standardize) {
    dataset <- mutate_if(dataset, is.numeric, ~ as.vector(scale(.)))
  }

  if (distance == "sq.euclidian") {
    d <- dist(dataset, method = "euclidean")^2
  } else if (distance == "gower") {
    d <- sapply(1:nrow(dataset), function(i) gower::gower_dist(dataset[i, ], dataset)) %>%
      as.dist()
  } else {
    d <- dist(dataset, method = distance)
  }
  hc_out <- hclust(d = d, method = method)
  as.list(environment()) %>% add_class("hclus")
}

#' Summary method for the hclus function
#'
#' @details See \url{https://radiant-rstats.github.io/docs/multivariate/hclus.html} for an example in Radiant
#'
#' @param object Return value from \code{\link{hclus}}
#' @param ... further arguments passed to or from other methods
#'
#' @examples
#' result <- hclus(shopping, vars = c("v1:v6"))
#' summary(result)
#'
#' @seealso \code{\link{hclus}} to generate results
#' @seealso \code{\link{plot.hclus}} to plot results
#'
#' @export
summary.hclus <- function(object, ...) {
  if (is.character(object)) {
    return(object)
  }

  cat("Hierarchical cluster analysis\n")
  cat("Data        :", object$df_name, "\n")
  if (!is.empty(object$data_filter)) {
    cat("Filter      :", gsub("\\n", "", object$data_filter), "\n")
  }
  cat("Variables   :", paste0(object$vars, collapse = ", "), "\n")
  cat("Method      :", object$method, "\n")
  cat("Distance    :", object$distance, "\n")
  cat("Standardize :", object$standardize, "\n")
  cat("Observations:", format_nr(length(object$hc_out$order), dec = 0), "\n")
  if (sum(object$anyCategorical) > 0 && object$distance != "gower") {
    cat("** When {factor} variables are included \"Gower\" distance is used **\n\n")
  }
}

#' Plot method for the hclus function
#'
#' @details See \url{https://radiant-rstats.github.io/docs/multivariate/hclus.html} for an example in Radiant
#'
#' @param x Return value from \code{\link{hclus}}
#' @param plots Plots to return. "change" shows the percentage change in within-cluster heterogeneity as respondents are grouped into different number of clusters, "dendro" shows the dendrogram, "scree" shows a scree plot of within-cluster heterogeneity
#' @param cutoff For large datasets plots can take time to render and become hard to interpret. By selection a cutoff point (e.g., 0.05 percent) the initial steps in hierarchical cluster analysis are removed from the plot
#' @param shiny Did the function call originate inside a shiny app
#' @param custom Logical (TRUE, FALSE) to indicate if ggplot object (or list of ggplot objects) should be returned. This option can be used to customize plots (e.g., add a title, change x and y labels, etc.). See examples and \url{https://ggplot2.tidyverse.org/} for options.
#' @param ... further arguments passed to or from other methods
#'
#' @examples
#' result <- hclus(shopping, vars = c("v1:v6"))
#' plot(result, plots = c("change", "scree"), cutoff = .05)
#' plot(result, plots = "dendro", cutoff = 0)
#'
#' @seealso \code{\link{hclus}} to generate results
#' @seealso \code{\link{summary.hclus}} to summarize results
#'
#' @export
plot.hclus <- function(x, plots = c("scree", "change", "pairwise_hc"),
                       cutoff = 0.05,
                       shiny = FALSE, custom = FALSE,
                       nr_clusters = 3, ...) {
  if (is.empty(plots)) {
    return(invisible())
  }
  if (is.character(x)) {
    return(invisible())
  }
  if (is_not(cutoff)) cutoff <- 0
  x$hc_out$height %<>% (function(x) x / max(x))

  plot_list <- list()
  if ("scree" %in% plots) {
    plot_list[["scree"]] <-
      x$hc_out$height[x$hc_out$height > cutoff] %>%
      data.frame(
        height = .,
        nr_clus = as.integer(length(.):1),
        stringsAsFactors = FALSE
      ) %>%
      ggplot(aes(x = factor(nr_clus, levels = nr_clus), y = height, group = 1)) +
      geom_line(color = "blue", linetype = "dotdash", linewidth = .7) +
      geom_point(color = "blue", size = 4, shape = 21, fill = "white") +
      scale_y_continuous(labels = scales::percent) +
      labs(
        title = "Scree plot",
        x = "# clusters",
        y = "Within-cluster heterogeneity"
      )
  }

  if ("change" %in% plots) {
    plot_list[["change"]] <-
      x$hc_out$height[x$hc_out$height > cutoff] %>%
      (function(x) (x - lag(x)) / lag(x)) %>%
      data.frame(
        bump = .,
        nr_clus = paste0((length(.) + 1):2, "-", length(.):1),
        stringsAsFactors = FALSE
      ) %>%
      na.omit() %>%
      ggplot(aes(x = factor(nr_clus, levels = nr_clus), y = bump)) +
      geom_bar(stat = "identity", alpha = 0.5, fill = "blue") +
      scale_y_continuous(labels = scales::percent) +
      labs(
        title = "Change in within-cluster heterogeneity",
        x = "# clusters",
        y = "Change in within-cluster heterogeneity"
      )
  }

  if ("dendro" %in% plots) {
    hc <- as.dendrogram(x$hc_out)
    xlab <- ""
    if (length(plots) > 1) {
      xlab <- "When dendrogram is selected no other plots can be shown.\nCall the plot function separately in Report > Rmd to view different plot types."
    }

    if (cutoff == 0) {
      plot(hc, main = "Dendrogram", xlab = xlab, ylab = "Within-cluster heterogeneity")
    } else {
      plot(
        hc,
        ylim = c(cutoff, 1), leaflab = "none",
        main = "Cutoff dendrogram", xlab = xlab, ylab = "Within-cluster heterogeneity"
      )
    }
    return(invisible())
  }

  if ("pairwise_hc" %in% plots) {
    clusters <- cutree(x$hc_out, k = nr_clusters)
    x$dataset$Cluster <- as.factor(clusters)
    vars <- colnames(x$dataset) %>% .[-length(.)]
    if (length(vars) >= 2) {
      p <- GGally::ggpairs(x$dataset,
                           columns = vars,
                           mapping = aes(color = Cluster),
                           upper = list(continuous = wrap("cor", size = 4)),
                           lower = list(continuous = wrap("points", alpha = 0.6)),
                           diag = list(continuous = wrap("densityDiag", alpha = 0.3))
      ) +
        theme_minimal() +
        labs(title = "Pairwise Scatter plot with Hierarchical clustering")
      if (custom) {
        return(p)
      } else {
        return(p)
      }
    } else {
      warning("Not enough variables to create a Pairwise scatter plot.")
    }
  }

  if (length(plot_list) > 0) {
    if (custom) {
      if (length(plot_list) == 1) return(plot_list[[1]]) else return(plot_list)
    } else {
      plot_output <- patchwork::wrap_plots(plot_list, ncol = min(length(plot_list), 2))
      if (isTRUE(shiny)) {
        return(plot_output)
      } else {
        print(plot_output)
        return(invisible())
      }
    }
  }
}

#' Add a cluster membership variable to the active dataset
#'
#' @details See \url{https://radiant-rstats.github.io/docs/multivariate/hclus.html} for an example in Radiant
#'
#' @param dataset Dataset to append to cluster membership variable to
#' @param object Return value from \code{\link{hclus}}
#' @param nr_clus Number of clusters to extract
#' @param name Name of cluster membership variable
#' @param ... Additional arguments
#'
#' @examples
#' hclus(shopping, vars = "v1:v6") %>%
#'   store(shopping, ., nr_clus = 3) %>%
#'   head()
#' @seealso \code{\link{hclus}} to generate results
#' @seealso \code{\link{summary.hclus}} to summarize results
#' @seealso \code{\link{plot.hclus}} to plot results
#'
#' @export
store.hclus <- function(dataset, object, nr_clus = 2, name = "", ...) {
  if (is.empty(name)) name <- paste0("hclus", nr_clus)
  indr <- indexr(dataset, object$vars, object$data_filter)
  hm <- rep(NA, indr$nr)
  hm[indr$ind] <- cutree(object$hc_out, nr_clus)
  dataset[[name]] <- as.factor(hm)
  dataset
}


