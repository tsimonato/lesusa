\name{les_aggregate}
\alias{les_aggregate}
\title{Aggregate the LES-USA parameter database to a user classification}
\usage{
les_aggregate(goods = NULL, regions = NULL, household = NULL,
              file = NULL, per = c("cu", "capita", "adult_equiv"),
              flagged = c("error", "keep", "renormalize"),
              cross_price = FALSE)
}
\arguments{
\item{goods, regions, household}{correspondences: a CSV path, a data.frame,
or a named vector. Native keys: \code{good} (goods); \code{state} (regions);
\code{decile}, \code{age}, optionally \code{state}, optionally \code{fam}
(household). A missing map collapses its dimension to one element. Claiming
\code{fam} composes the v0.8 family layer at call time by biproportional
fitting (see the README caveats). Every native element must map exactly
once; violations are errors that name the offenders.}

\item{file}{output basename: writes \code{<file>.har} (GEMPACK),
\code{<file>.csv} and \code{<file>_cells.csv}. \code{NULL} writes nothing.}

\item{per}{report levels per \code{"cu"} (default), \code{"capita"} or
\code{"adult_equiv"}. Divides gamma, M_bar, x and Gamma only; shares and
elasticities are bit-identical across settings.}

\item{flagged}{what to do when an aggregated \code{x_G <= 0}:
\code{"error"} (default) stops naming the cells; \code{"keep"} passes the
algebraic values through with \code{flag_zero = 1}; \code{"renormalize"}
floors x at 0, warns, and reports the adding-up break in the audit.}

\item{cross_price}{also return and audit the full cross-price block.}
}
\value{
Invisibly, a list: \code{par} (one row per output cell x commodity:
\code{beta}, \code{gamma}, \code{x}, \code{w}, \code{eta}, \code{eps_own},
\code{flag_zero}, \code{n_neg_absorbed}), \code{cells} (one row per output
cell: \code{N_cu}, \code{M_bar}, \code{Gamma}, \code{SUP}, \code{S},
\code{phi}, demographics and honesty columns), \code{audit} (the printed
consistency checks), and \code{cross} when \code{cross_price = TRUE}.
}
\description{
Aggregates the shipped 51-state x 10-decile x 5-age x 42-good Stone-Geary
(LES) parameter grid (release cut \code{frisch_friedman_v1.3.0-tier2},
2017-2019) to arbitrary user classifications, exactly at the base point:
gamma and mean outlay aggregate by CU mass, beta by supernumerary mass, and
all derived quantities are re-derived from closed forms rather than
averaged. Every call audits adding-up, Engel aggregation, the subsistence
share and exact level reproduction (plus homogeneity and Cournot with
\code{cross_price = TRUE}) and refuses to return an inconsistent result.
}
\examples{
cdir <- system.file("correspondence", package = "lesusa")
g16 <- read.csv(file.path(cdir, "goods_42_to_16.csv"), comment.char = "#")
hq <- read.csv(file.path(cdir, "household_decile_to_quintile.csv"),
               comment.char = "#")
res <- les_aggregate(goods = g16, household = hq)
str(res$audit)
}
