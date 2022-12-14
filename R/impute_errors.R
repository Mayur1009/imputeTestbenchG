#' Function working as testbench for comparison of imputing models
#'
#' @param dataIn input \code{\link[stats]{ts}} for testing
#' @param smps chr string indicating sampling type for generating missing data, see details
#' @param methods chr string of imputation methods to use, one to many.  A user-supplied function can be included if \code{MethodPath} is used, see details.
#' @param methodPath chr string of location of script containing one or more functions for the proposed imputation method(s)
#' @param errorParameter chr string indicating which error type to use, acceptable values are \code{"rmse"} (default), \code{"mae"}, or \code{"mape"}.  Alternatively, a user-supplied function can be passed if \code{errorPath} is used, see details.
#' @param errorPath chr string of location of script containing one or more error functions for evaluating imputations
#' @param blck numeric indicating block sizes as a percentage of the sample size for the missing data, applies only if \code{smps = 'mar'}
#' @param blckper logical indicating if the value passed to \code{blck} is a percentage of the sample size for missing data, otherwise \code{blck} indicates number of observations
#' @param missPercentFrom numeric from which percent of missing values to be considered
#' @param missPercentTo numeric for up to what percent missing values are to be considered
#' @param interval numeric for interval between consecutive missPercent values
#' @param repetition numeric for repetitions to be done for each missPercent value
#' @param addl_arg arguments passed to other imputation methods as a list of lists, see details.
#'
#' @details
#' The default methods for \code{impute_errors} are \code{\link[zoo]{na.approx}}, \code{\link[forecast]{na.interp}}, \code{\link[imputeTS]{na_interpolation}}, \code{\link[zoo]{na.locf}},  and \code{\link[imputeTS]{na_mean}}.  See the help file for each for additional documentation. Additional arguments for the imputation functions are passed as a list of lists to the \code{addl_arg} argument, where the list contains one to many elements that are named by the \code{methods}. The elements of the master list are lists with arguments for the relevant methods. See the examples.
#'
#' A user-supplied function can also be passed to \code{methods} as an additional imputation method.  A character string indicating the path of the function must also be supplied to \code{methodPath}.  The path must point to a function where the first argument is the time series to impute.
#'
#' An alternative error function can also be passed to \code{errorParameter} if \code{errorPath} is not \code{NULL}.  The function specified in \code{errorPath} must have two arguments where the first is a vector for the observed time series and the second is a vector for the predicted time series.
#'
#' The \code{smps} argument indicates the type of sampling for generating missing data.  Options are \code{smps = 'mcar'} for missing completely at random and \code{smps = 'mar'} for missing at random.  Additional information about the sampling method is described in \code{\link{sample_dat}}. The relevant arguments for \code{smps = 'mar'} are \code{blck} and \code{blckper} which greatly affect the sampling method.
#'
#' Infinite comparisons are removed with a warning if \code{errorParameter = 'mape'}. This occurs if any of the observed values in the original time series are zero.  Error estimates for such datasets are evaluated only for non-zero observations.
#'
#' @import forecast
#' @importFrom imputeTS na_interpolation na_mean
#' @importFrom stats ts
#' @import zoo parallel doParallel
#' @importFrom foreach '%dopar%' foreach
#'
#' @seealso \code{\link{sample_dat}}
#'
#' @return Returns an error comparison for imputation methods as an \code{errprof} object.  This object is structured as a list where the first two elements are named \code{Parameter} and \code{MissingPercent} that describe the error metric used to assess the imputation methods and the intervals of missing observations as percentages, respectively.  The remaining elements are named as the chr strings in \code{methods} of the original function call.  Each remaining element contains a numeric vector of the average error at each missing percent of observations.  The \code{errprof} object also includes an attribute named \code{errall} as an additional list that contains all of the error estimates for every imputation method and repetition.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # default options
#' aa <- impute_errors(dataIn = nottem)
#' aa
#' plot_errors(aa)
#'
#' # change the simulation for missing obs
#' aa <- impute_errors(dataIn = nottem, smps = 'mar')
#' aa
#' plot_errors(aa)
#'
#' # use one interpolation method, increase repetitions
#' aa <- impute_errors(dataIn = nottem, methods = 'na.interp', repetition = 100)
#' aa
#' plot_errors(aa)
#'
#' # change the error metric
#' aa <- impute_errors(dataIn = nottem, errorParameter = 'mae')
#' aa
#' plot_errors(aa)
#'
#' # passing additional arguments to imputation methods
#' impute_errors(dataIn = nottem, addl_arg = list(na_mean = list(option = 'mode')))
#' }
impute_errors <- function(dataIn, smps = 'mcar', methods = c("na.approx", "na.interp", "na_interpolation", "na.locf", "na_mean"),  methodPath = NULL, errorParameter = 'rmse', errorPath = NULL, blck = 50, blckper = TRUE, missPercentFrom = 10, missPercentTo = 90, interval = 10, repetition = 10, addl_arg = NULL, n_cores = detectCores())
{

  # source method if provided
  if(!is.null(methodPath))
    source(methodPath)

  # source error if provided
  if(!is.null(errorPath))
    source(errorPath)

  # check if methods are okay
  meth_chk <- sapply(methods, function(x) exists(x), simplify = FALSE)
  if(any(!unlist(meth_chk))){
    no_func <- names(meth_chk)[!unlist(meth_chk)]
    no_func <- paste(no_func, collapse = ', ')
    stop(no_func, ' does not exist')
  }

  # check if errorParameter is okay
  if(!exists(errorParameter))
    stop(errorParameter, ' does not exist')
  
  registerDoParallel(cores = n_cores)

  # missing percentages to evaluate
  percs <- seq(missPercentFrom, missPercentTo, interval)

  # create master list for output
  errall <- vector('list', length = length(percs))
  errall <- rep(list(errall), length(methods))
  names(errall) <- methods

  # fill arguments with list
  args <- rep(list(list()), length = length(methods))
  names(args) <- methods
  if(!is.null(addl_arg))
    args[names(addl_arg)] <- addl_arg

  # create missing data for each missing percentage
  # take error estimates for each repetition
  for(x in seq_along(percs)){

    # create the missing data for imputation
    b <- percs[x]

    out <- sample_dat(dataIn, smps = smps, b = b, repetition = repetition,
      blck = blck, blckper = blckper, plot = FALSE)

    # go through each imputation method
    for(method in methods){

      # arguments and method to eval
      arg <- list(args[[method]])
      toeval <- paste0('do.call(', method, ', args = c(list(y),', arg, '))')
      toeval <- gsub(',)', ')', toeval)

      # iterate through each repetition, get predictions, get error
      errs <- mclapply(out, function(y){
        filled <- eval(parse(text = toeval))
        errout <- paste0(errorParameter, '(dataIn, filled)')
        eval(parse(text = errout))
        },mc.cores=n_cores)

      # append to master list
      errall[[method]][[x]] <- unlist(errs)

    }

  }

  ##
  # summarize for output
  out <- mclapply(errall, function(x) unlist(lapply(x, mean)), mc.cores=n_cores)
  out <- c(list(Parameter = errorParameter, MissingPercent = percs), out)

  # create errprof object
  out <- structure(
    .Data = out,
    class = c('errprof', 'list'),
    errall = errall
  )

  return(out)

}
