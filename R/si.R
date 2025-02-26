#' Compute Support Intervals
#'
#' A support interval contains only the values of the parameter that predict the observed data better
#' than average, by some degree *k*; these are values of the parameter that are associated with an
#' updating factor greater or equal than *k*. From the perspective of the Savage-Dickey Bayes factor, testing
#' against a point null hypothesis for any value within the support interval will yield a Bayes factor smaller
#' than *1/k*.
#' \cr \cr
#' \strong{For more info, in particular on specifying correct priors for factors with more than 2 levels,
#' see [the Bayes factors vignette](https://easystats.github.io/bayestestR/articles/bayes_factors.html).}
#'
#' @param BF The amount of support required to be included in the support interval.
#' @inheritParams bayesfactor_parameters
#' @inheritParams hdi
#' @inherit hdi seealso
#' @family ci
#'
#' @details This method is used to compute support intervals based on prior and posterior distributions.
#' For the computation of support intervals, the model priors must be proper priors (at the very least
#' they should be *not flat*, and it is preferable that they be *informative* - note
#' that by default, `brms::brm()` uses flat priors for fixed-effects; see example below).
#'
#' \subsection{Choosing a value of `BF`}{
#' The choice of `BF` (the level of support) depends on what we want our interval to represent:
#' \itemize{
#'   \item A `BF` = 1 contains values whose credibility is not decreased by observing the data.
#'   \item A `BF` > 1 contains values who received more impressive support from the data.
#'   \item A `BF` < 1 contains values whose credibility has *not* been impressively decreased by observing the data.
#'   Testing against values outside this interval will produce a Bayes factor larger than 1/`BF` in support of
#'   the alternative. E.g., if an SI (BF = 1/3) excludes 0, the Bayes factor against the point-null will be larger than 3.
#' }
#' }
#'
#' @inheritSection bayesfactor_parameters Setting the correct `prior`
#'
#' @note There is also a [`plot()`-method](https://easystats.github.io/see/articles/bayestestR.html) implemented in the \href{https://easystats.github.io/see/}{\pkg{see}-package}.
#'
#' @return
#' A data frame containing the lower and upper bounds of the SI.
#' \cr
#' Note that if the level of requested support is higher than observed in the data, the
#' interval will be `[NA,NA]`.
#'
#' @examples
#' library(bayestestR)
#'
#' prior <- distribution_normal(1000, mean = 0, sd = 1)
#' posterior <- distribution_normal(1000, mean = .5, sd = .3)
#'
#' si(posterior, prior)
#' \dontrun{
#' # rstanarm models
#' # ---------------
#' library(rstanarm)
#' contrasts(sleep$group) <- contr.orthonorm # see vingette
#' stan_model <- stan_lmer(extra ~ group + (1 | ID), data = sleep)
#' si(stan_model)
#' si(stan_model, BF = 3)
#'
#' # emmGrid objects
#' # ---------------
#' library(emmeans)
#' group_diff <- pairs(emmeans(stan_model, ~group))
#' si(group_diff, prior = stan_model)
#'
#' # brms models
#' # -----------
#' library(brms)
#' contrasts(sleep$group) <- contr.orthonorm # see vingette
#' my_custom_priors <-
#'   set_prior("student_t(3, 0, 1)", class = "b") +
#'   set_prior("student_t(3, 0, 1)", class = "sd", group = "ID")
#'
#' brms_model <- brm(extra ~ group + (1 | ID),
#'   data = sleep,
#'   prior = my_custom_priors
#' )
#' si(brms_model)
#' }
#' @references
#' Wagenmakers, E., Gronau, Q. F., Dablander, F., & Etz, A. (2018, November 22). The Support Interval. \doi{10.31234/osf.io/zwnxb}
#'
#' @export
si <- function(posterior, prior = NULL, BF = 1, verbose = TRUE, ...) {
  UseMethod("si")
}

#' @rdname si
#' @export
si.numeric <- function(posterior, prior = NULL, BF = 1, verbose = TRUE, ...) {
  if (is.null(prior)) {
    prior <- posterior
    if (verbose) {
      warning(insight::format_message(
        "Prior not specified!",
        "Support intervals ('si') can only be computed for Bayesian models with proper priors.",
        "Please specify priors (with column order matching 'posterior')."
      ), call. = FALSE)
    }
  }
  prior <- data.frame(X = prior)
  posterior <- data.frame(X = posterior)

  # Get SIs
  out <- si.data.frame(
    posterior = posterior, prior = prior,
    BF = BF, verbose = verbose, ...
  )
  out$Parameter <- NULL
  out
}

#' @rdname si
#' @export
si.stanreg <- function(posterior, prior = NULL,
                       BF = 1, verbose = TRUE,
                       effects = c("fixed", "random", "all"),
                       component = c("conditional", "location", "zi", "zero_inflated", "all", "smooth_terms", "sigma", "distributional", "auxiliary"),
                       parameters = NULL,
                       ...) {
  cleaned_parameters <- insight::clean_parameters(posterior)
  effects <- match.arg(effects)
  component <- match.arg(component)

  samps <- .clean_priors_and_posteriors(posterior, prior,
    verbose = verbose,
    effects = effects, component = component,
    parameters = parameters
  )

  # Get SIs
  temp <- si.data.frame(
    posterior = samps$posterior, prior = samps$prior,
    BF = BF, verbose = verbose, ...
  )

  out <- .prepare_output(temp, cleaned_parameters, inherits(posterior, "stanmvreg"))

  attr(out, "ci_method") <- "SI"
  attr(out, "object_name") <- .safe_deparse(substitute(posterior))
  class(out) <- class(temp)
  attr(out, "plot_data") <- attr(temp, "plot_data")

  out
}


#' @rdname si
#' @export
si.brmsfit <- si.stanreg

#' @rdname si
#' @export
si.blavaan <- si.stanreg


#' @rdname si
#' @export
si.emmGrid <- function(posterior, prior = NULL,
                       BF = 1, verbose = TRUE, ...) {
  samps <- .clean_priors_and_posteriors(posterior, prior,
    verbose = verbose
  )

  # Get SIs
  out <- si.data.frame(
    posterior = samps$posterior, prior = samps$prior,
    BF = BF, verbose = verbose, ...
  )

  attr(out, "ci_method") <- "SI"
  attr(out, "object_name") <- .safe_deparse(substitute(posterior))
  out
}

#' @export
si.emm_list <- si.emmGrid


#' @rdname si
#' @export
si.data.frame <- function(posterior, prior = NULL, BF = 1, verbose = TRUE, ...) {
  if (length(BF) > 1) {
    SIs <- lapply(BF, function(i) {
      si(posterior, prior = prior, BF = i, verbose = verbose, ...)
    })
    out <- do.call(rbind, SIs)

    attr(out, "plot_data") <- attr(SIs[[1]], "plot_data")
    class(out) <- unique(c("bayestestR_si", "bayestestR_ci", class(out)))
    return(out)
  }

  if (is.null(prior)) {
    prior <- posterior
    warning(insight::format_message(
      "Prior not specified!",
      "Support intervals ('si') can only be computed for Bayesian models with proper priors.",
      "Please specify priors (with column order matching 'posterior')."
    ), call. = FALSE)
  }

  sis <- matrix(NA, nrow = ncol(posterior), ncol = 2)
  for (par in seq_along(posterior)) {
    sis[par, ] <- .si(posterior[[par]],
      prior[[par]],
      BF = BF, ...
    )
  }

  out <- data.frame(
    Parameter = colnames(posterior),
    CI = BF,
    CI_low = sis[, 1],
    CI_high = sis[, 2],
    stringsAsFactors = FALSE
  )

  attr(out, "ci_method") <- "SI"
  attr(out, "plot_data") <- .make_BF_plot_data(posterior, prior, 0, 0, ...)$plot_data
  class(out) <- unique(c("bayestestR_si", "see_si", "bayestestR_ci", "see_ci", class(out)))

  out
}


#' @export
si.stanfit <- function(posterior, prior = NULL, BF = 1, verbose = TRUE, effects = c("fixed", "random", "all"), ...) {
  si(insight::get_parameters(posterior, effects = effects))
}

#' @export
si.get_predicted <- function(posterior, ...) {
  out <- si(as.data.frame(t(posterior)), ...)
  attr(out, "object_name") <- .safe_deparse(substitute(posterior))
  out
}

# Helper ------------------------------------------------------------------



#' @keywords internal
.si <- function(posterior, prior, BF = 1, extend_scale = 0.05, precision = 2^8, ...) {
  insight::check_if_installed("logspline")

  if (isTRUE(all.equal(prior, posterior))) {
    return(c(NA, NA))
  }

  x <- c(prior, posterior)
  x_range <- range(x)
  x_rangex <- stats::median(x) + 7 * stats::mad(x) * c(-1, 1)
  x_range <- c(
    max(c(x_range[1], x_rangex[1])),
    min(c(x_range[2], x_rangex[2]))
  )

  extension_scale <- diff(x_range) * extend_scale
  x_range <- x_range + c(-1, 1) * extension_scale

  x_axis <- seq(x_range[1], x_range[2], length.out = precision)

  f_prior <- .logspline(prior, ...)
  f_posterior <- .logspline(posterior, ...)
  d_prior <- logspline::dlogspline(x_axis, f_prior)
  d_posterior <- logspline::dlogspline(x_axis, f_posterior)

  relative_d <- d_posterior / d_prior

  crit <- relative_d >= BF

  cp <- rle(c(stats::na.omit(crit)))
  if (length(cp$lengths) > 3) {
    warning("More than 1 SI detected. Plot the result to investigate.", call. = FALSE)
  }

  x_supported <- stats::na.omit(x_axis[crit])
  if (length(x_supported) < 2) {
    return(c(NA, NA))
  } else {
    range(x_supported)
  }
}
