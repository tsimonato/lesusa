# schema.R -- internal: load and validate the shipped star schema.
# Not exported. The data contract lives in spec 073 D2; the builder is
# data-raw/build_les_usa_rds.R.

.les_env <- new.env(parent = emptyenv())

les_data <- function() {
  if (!is.null(.les_env$les)) return(.les_env$les)
  path <- getOption("lesusa.data_path",
                    default = system.file("extdata", "les_usa.rds",
                                          package = "lesusa"))
  if (is.null(path) || !nzchar(path) || !file.exists(path))
    stop("les_usa.rds not found. Install the package, or point ",
         "options(lesusa.data_path=) at a built rds.", call. = FALSE)
  les <- readRDS(path)

  need <- c("par", "cells", "goods", "states",
            "fam_tilts", "fam_margins", "fam_cells", "meta")
  miss <- setdiff(need, names(les))
  if (length(miss))
    stop("les_usa.rds is missing table(s): ", paste(miss, collapse = ", "),
         call. = FALSE)
  stopifnot(
    nrow(les$par) == 107100L, nrow(les$cells) == 2550L,
    nrow(les$goods) == 42L, nrow(les$states) == 51L,
    nrow(les$fam_tilts) == 480L, nrow(les$fam_margins) == 30L,
    nrow(les$fam_cells) == 15300L,
    !anyNA(les$par$beta), !anyNA(les$par$gamma),
    all(les$cells$N_cu >= 0), all(les$cells$M_bar > 0),
    all(les$cells$S_c > 0 & les$cells$S_c < 1))
  # adding-up at the native grid: sum(beta) = 1 per cell
  sb <- rowsum(les$par$beta, les$par$cell_id)
  if (max(abs(sb - 1)) > 1e-10)
    stop("shipped data violates adding-up: max|sum(beta)-1| = ",
         format(max(abs(sb - 1))), call. = FALSE)
  .les_env$les <- les
  les
}
