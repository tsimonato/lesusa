\name{les_aggregate}
\alias{les_aggregate}
\title{Aggregate the LES-USA parameter database to a user classification}
\usage{
les_aggregate(goods = NULL, regions = NULL, household = NULL,
              file = NULL, per = c("cu", "capita", "adult_equiv"),
              flagged = c("error", "keep", "renormalize"),
              cross_price = FALSE,
              eta_over = c("error", "warn", "keep"))
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
floors x at 0, warns, and reports the adding-up break in the audit.
Since the v1.0 cube (release cut \code{frisch_friedman_v1.6.0-tier2}, cube
v1.2) every NATIVE row has \code{x > 0} by construction and
\code{eta = beta/w <= 4.89} (the construction band of 2026-09-14), so this never fires
on the shipped inputs: exact aggregation of positive native rows keeps
every output \code{x_G} positive. The argument exists for alternative or
invalid inputs.}

\item{cross_price}{also return and audit the full cross-price block.}

\item{eta_over}{what to do when an output row's \code{eta = beta/w} exceeds
the export ceiling \code{ETA_EXPORT} (5): \code{"error"} (default) stops
before anything is returned or written, naming the worst rows;
\code{"warn"} returns the exact aggregates with a warning; \code{"keep"}
returns them silently. In every mode \code{audit$n_eta_above} and
\code{audit$eta_max} carry the count and the maximum.}
}
\value{
Invisibly, a list: \code{par} (one row per output cell x commodity:
\code{beta}, \code{gamma}, \code{x}, \code{w}, \code{eta}, \code{eps_own},
\code{flag_zero}, \code{n_neg_absorbed}), \code{cells} (one row per output
cell: \code{N_cu}, \code{M_bar}, \code{Gamma}, \code{SUP}, \code{S},
\code{phi}, demographics and honesty columns), \code{audit} (the printed
consistency checks, including \code{n_eta_above} and \code{eta_max}), and
\code{cross} when \code{cross_price = TRUE}.
}
\description{
Aggregates the shipped 51-state x 10-decile x 5-age x 42-good Stone-Geary
(LES) parameter grid (release cut \code{frisch_friedman_v1.5.0-tier2},
cube v1.1, 2017-2019) to arbitrary user classifications, exactly at the
base point:
gamma and mean outlay aggregate by CU mass, beta by supernumerary mass, and
all derived quantities are re-derived from closed forms rather than
averaged. Every call audits adding-up, Engel aggregation, the subsistence
share and exact level reproduction (plus homogeneity and Cournot with
\code{cross_price = TRUE}) and refuses to return an inconsistent result.
}
\section{The export band on eta}{

Two numbers, and they answer different questions. Every native row has
\code{eta = beta/w <= 4.89} by construction (the construction band). Exports
are exact aggregates of those rows, not bounded copies of them: an aggregate
weights beta by supernumerary mass and x by CU mass, so merging cells whose
share of a luxury rises with the budget lifts the aggregate above the largest
row it merges -- by up to 7.2\% on this cube. So the band does not mechanically
deliver the export ceiling \code{ETA_EXPORT} (5). Of the 178 classifications
the release sweep drives (the shipped correspondences plus the maps built from
the cube's own keys), 16 come out above 5, all of them merging across income
deciles inside a state; the worst is \code{g42 x r51 x q_fam6} at 5.24. The
CGE grid (16 goods x 51 states x 10 deciles) stays under, at 4.96. A two-cell
merge of very different budgets can go further still.

What is guaranteed is therefore not that no aggregate exceeds 5, but that none
is handed to you quietly: the function re-checks \code{eta} on every output row
and, by default, \strong{refuses} the call (\code{eta_over = "error"}), naming
the rows, when any exceeds \code{ETA_EXPORT}. Nothing above the ceiling is
returned or written unless you ask: \code{eta_over = "warn"} or \code{"keep"}
opts into the exact aggregates, which are never altered. Coarsen or split the
map differently, or opt in knowingly. The count is in
\code{audit$n_eta_above} and the maximum in \code{audit$eta_max}.
}

\examples{
cdir <- system.file("correspondence", package = "lesusa")
g16 <- read.csv(file.path(cdir, "goods_42_to_16.csv"), comment.char = "#")
hq <- read.csv(file.path(cdir, "household_decile_to_quintile.csv"),
               comment.char = "#")
res <- les_aggregate(goods = g16, household = hq)
str(res$audit)
}
