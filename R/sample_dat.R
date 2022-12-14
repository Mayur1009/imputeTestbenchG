#' Sample time series data
#'
#' Sample time series using completely at random (MCAR) or at random (MAR)
#'
#' @param datin input numeric vector
#' @param smps chr string of sampling type to use, options are \code{"mcar"} or \code{"mar"}
#' @param repetition numeric for repetitions to be done for each missPercent value
#' @param b numeric indicating the total amount of missing data as a percentage to remove from the complete time series
#' @param blck numeric indicating block sizes as a proportion of the sample size for the missing data
#' @param blckper logical indicating if the value passed to \code{blck} is a proportion of \code{missper}, i.e., blocks are to be sized as a percentage of the total size of the missing data
#' @param plot logical indicating if a plot is returned showing the sampled data, plots only the first repetition
#'
#' @return Input data with \code{NA} values for the sampled observations if \code{plot = FALSE}, otherwise a plot showing the missing observations over the complete dataset.
#'
#' The missing data if \code{smps = 'mar'} are based on random sampling by blocks.  The start location of each block is random and overlapping blocks are not counted uniquely for the required sample size given by \code{b}.  Final blocks are truncated to ensure the correct value of \code{b} is returned.  Blocks are fixed at 1 if the proportion is too small, in which case \code{"mcar"} should be used.  Block sizes are also truncated to the required sample size if the input value is too large if \code{blckper = FALSE}.  For the latter case, this is the same as setting \code{blck = 1} and \code{blckper = TRUE}.
#'
#' For all cases, the first and last observation will never be removed to allow comparability of interpolation schemes.  This is especially relevant for cases when \code{b} is large and \code{smps = 'mar'} is used.  For example, \code{method = na.approx} will have rmse = 0 for a dataset where the removed block includes the last n observations. This result could provide misleading information in comparing methods.
#'
#' @export
#'
#' @import dplyr ggplot2 doParallel
#' @importFrom foreach '%dopar%' foreach
#'
#' @examples
#' a <- rnorm(1000)
#'
#' # default sampling
#' sample_dat(a)
#'
#' # use mar sampling
#' sample_dat(a, smps = 'mar')
#'
#' # show a plot of one repetition
#' sample_dat(a, plot = TRUE)
#'
#' # show a plot of one repetition, mar sampling
#' sample_dat(a, smps = 'mar', plot = TRUE)
#'
#' # change plot aesthetics
#' library(ggplot2)
#' p <- sample_dat(a, plot = TRUE)
#' p + scale_colour_manual(values = c('black', 'grey'))
#' p + theme_minimal()
#' p + ggtitle('Example of simulating missing data')
sample_dat <- function(datin, smps = 'mcar', repetition = 10, b = 10, blck = 50, blckper = TRUE, plot = FALSE){

  # sanity checks
  if(!smps %in% c('mcar', 'mar'))
    stop('smps must be mcar or mar')

  # upper sample value
  upp <- length(datin) -1

  # sample to take for missing data given x
  pool <- 2:upp
  torm <- round(length(datin) * b/100)
  out <- vector('list', length = repetition)
  
  # sampling complately at random
  if(smps == 'mcar'){

    # label for plot
    lab <- paste0('b = ', b, ', smps = "', smps, '"')

    # for(i in 1:repetition){
    # 
    #   c <- sample(pool, torm, replace = FALSE)
    #   datsmp <- datin
    #   datsmp[c] <- NA
    #   out[i] <- data.frame(datsmp)
    # 
    # }
    
    out2 <- foreach(i = 1:repetition) %dopar% {
      c <- sample(pool, torm, replace = FALSE)
      datsmp <- datin
      datsmp[c] <- NA
      datsmp
    }

  }

  # sampling at random
  if(smps == 'mar'){

    # label for plot
    lab <- paste0('b = ', b, ', smps = "', smps, '", blck = ', blck, ', blckper = ', blckper)

    # block size
    if(blckper){

      if(blck > 100 | blck < 0)
        stop('block must be between 0 - 100 if blckper = T')

      blck <- pmax(1, round(torm * blck/100))

    } else {

      if(blck < 1)
        stop('block must be at least one if blckper = F')

      blck <- pmin(torm, blck)

    }

    # get number of samples for initial grab
    blck_sd <- floor(torm/blck)

    # create samples for each repetition
    # for(i in 1:repetition){
    # 
    #   # pool is the number of obs up to the max minus blck size
    #   # ensures that those on the right do not overlap the end
    #   pool <- 2:(length(datin) - blck + 1)
    # 
    #   # initial grab
    #   grbs <- sample(pool, blck_sd, replace = F) %>%
    #     sapply(function(x) x:(x + blck - 1)) %>%
    #     c %>%
    #     unique %>%
    #     .[. <= upp] %>%
    #     sort
    # 
    #   # adjust sampling pool and number of samples left
    #   pool <- 2:upp %>%
    #     .[!. %in% grbs]
    #   lft <- torm - length(grbs)
    # 
    #   # continue sampling one block at a time until enough samples in missper
    #   while(lft > 0){
    # 
    #     # take one sample with block size as minimum between block of samples left
    #     grbs_tmp <- sample(pool, 1, replace = F) %>%
    #           .:(. + pmin(lft, blck) - 1)
    # 
    #     # append new sample to initial grab
    #     grbs <- c(grbs, grbs_tmp) %>%
    #       unique %>%
    #       sort %>%
    #       .[. <= upp]
    # 
    #     # update samples left and sample pool
    #     lft <- torm - length(grbs)
    # 
    #     pool <- pool[!pool %in% grbs]
    # 
    #   }
    # 
    # # append for each repetition
    # datsmp <- datin
    # datsmp[grbs] <- NA
    # out[i] <- data.frame(datsmp)
    # 
    # }
    
    out2 <- foreach(i = 1:repetition) %dopar% {
      # pool is the number of obs up to the max minus blck size
      # ensures that those on the right do not overlap the end
      pool <- 2:(length(datin) - blck + 1)
      
      # initial grab
      grbs <- sample(pool, blck_sd, replace = F) %>%
        sapply(function(x) x:(x + blck - 1)) %>%
        c %>%
        unique %>%
        .[. <= upp] %>%
        sort
      
      # adjust sampling pool and number of samples left
      pool <- 2:upp %>%
        .[!. %in% grbs]
      lft <- torm - length(grbs)
      
      # continue sampling one block at a time until enough samples in missper
      while(lft > 0){
        
        # take one sample with block size as minimum between block of samples left
        grbs_tmp <- sample(pool, 1, replace = F) %>%
          .:(. + pmin(lft, blck) - 1)
        
        # append new sample to initial grab
        grbs <- c(grbs, grbs_tmp) %>%
          unique %>%
          sort %>%
          .[. <= upp]
        
        # update samples left and sample pool
        lft <- torm - length(grbs)
        
        pool <- pool[!pool %in% grbs]
        
      }
      
      # append for each repetition
      datsmp <- datin
      datsmp[grbs] <- NA
      datsmp
    }

  }

  out <- out2
  # outplot for plot, otherwise return sampled data
  if(plot){

    miss <- is.na(out[[1]])
    toplo <- data.frame(x = 1:length(datin), y = datin, col = 'Retained', stringsAsFactors = FALSE)
    toplo$col[miss] <- 'Removed'
    p <- ggplot(toplo, aes(x = x, y = y, shape = col, colour = col)) +
      scale_shape_manual(values = c(21, 16)) +
      scale_colour_manual(values = c('black', '#00BFC4')) +
      geom_point(alpha = 0.75) +
      theme_bw() +
      theme(
        legend.title = element_blank(),
        plot.title = element_text(size = 12),
        legend.position = 'top',
        legend.key = element_blank()
        ) +
      ggtitle(lab)
    return(p)

  }

  return(out)

}
