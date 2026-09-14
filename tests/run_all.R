# run_all.R -- spec 073 D7 test driver. Two modes:
#   * source mode:    Rscript tests/run_all.R   from release/cge_bridge/ or
#                     the les_usa repo root (sources R/, uses inst/ data)
#   * installed mode: under R CMD check, using the installed lesusa namespace
# Case files live in tests/cases/ so that R CMD check does not execute them
# standalone: they need this driver's environment (corr_file, CUT_DIR, the
# internal functions).

# Locate the package source tree (the repo root has its own DESCRIPTION, so
# test for the package's R files, not for DESCRIPTION).
for (d in c(".", "release/cge_bridge", "..")) {
  if (file.exists(file.path(d, "R", "aggregate.R"))) { setwd(d); break }
}

if (file.exists("R/aggregate.R")) {                       # source mode
  for (f in sort(list.files("R", "\\.R$", full.names = TRUE))) source(f)
  options(lesusa.data_path = "inst/extdata/les_usa.rds")
  corr_dir <- "inst/correspondence"
} else {                                                  # installed mode
  library(lesusa)
  les_data    <- lesusa:::les_data
  compose_fam <- lesusa:::compose_fam
  corr_dir <- system.file("correspondence", package = "lesusa")
}
corr_file <- function(f) file.path(corr_dir, f)
CUT_DIR <- Sys.getenv("LESUSA_CUT", "../versions/frisch_friedman_v1.6.0-tier2")

case_dir <- if (dir.exists("tests/cases")) "tests/cases" else "cases"
tests <- sort(list.files(case_dir, "^t[0-9]{2}.*\\.R$", full.names = TRUE))
if (!length(tests)) stop("no test cases found under ", case_dir)
fails <- 0L
for (tf in tests) {
  cat("\n==== ", basename(tf), " ====\n", sep = "")
  ok <- tryCatch({ source(tf, local = new.env()); TRUE },
                 error = function(e) {
                   cat("FAIL:", conditionMessage(e), "\n"); FALSE
                 })
  if (!ok) fails <- fails + 1L
}
cat(sprintf("\n%d/%d test files passed\n", length(tests) - fails,
            length(tests)))
if (fails > 0L) stop(fails, " test file(s) failed")
