
<!-- README.md is generated from README.Rmd. Please edit that file -->

# imputeTestbenchG

<!-- badges: start -->

[![CRAN
status](https://www.r-pkg.org/badges/version/imputeTestbenchG)](https://CRAN.R-project.org/package=imputeTestbenchG)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

## Installation

``` r
# install.packages("devtools")
devtools::install_github("Mayur1009/imputeTestbenchG")
```

\####Load the package:

``` r
library(imputeTestbench)
```

#### Basic use

``` r
a <- impute_errors(data = nottem)
a
#> $Parameter
#> [1] "rmse"
#> 
#> $MissingPercent
#> [1] 10 20 30 40 50 60 70 80 90
#> 
#> $na.approx
#> [1]  0.8484444  1.4986629  2.0158453  2.4057743  3.7973749  5.1975195  6.4614848
#> [8]  8.6839006 10.2780148
#> 
#> $na.interp
#> [1]  0.7374866  1.1582693  1.4285136  1.6482360  1.8969032  2.1065006  2.3426693
#> [8]  2.7581197 10.2780148
#> 
#> $na_interpolation
#> [1]  0.8484444  1.4986629  2.0158453  2.4057743  3.7973749  5.1975195  6.4614848
#> [8]  8.6839006 10.2780148
#> 
#> $na.locf
#> [1]  1.679254  2.764380  3.910782  4.802727  6.189560  7.884283  8.982295
#> [8] 10.387566 11.480185
#> 
#> $na_mean
#> [1] 2.721977 3.872511 4.690561 5.348078 6.141582 6.637008 7.196776 7.760968
#> [9] 8.257784
plot_errors(a, plotType = 'line')
```

<img src="man/figures/README-unnamed-chunk-4-1.png" width="100%" />
