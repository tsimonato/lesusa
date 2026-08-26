# t05 -- AC6: the three flagged policies on a map that isolates a native
# cell carrying an x <= 0 row (found from the data, not hard-coded).
les <- les_data()
sup <- les$cells$M_bar - rowsum(les$par$gamma, les$par$cell_id)[
  as.character(les$cells$cell_id), 1L]
x_nat <- les$par$gamma + les$par$beta *
  sup[match(les$par$cell_id, les$cells$cell_id)]
bad_cell <- les$par$cell_id[which(x_nat <= 0)[1L]]
stopifnot(length(bad_cell) == 1L, !is.na(bad_cell))

hmap <- data.frame(decile = les$cells$decile, age = les$cells$age,
                   state = les$cells$state,
                   HH = ifelse(les$cells$cell_id == bad_cell, "BAD", "REST"),
                   stringsAsFactors = FALSE)
gid <- data.frame(good = les$goods$good, COM = paste0("G", seq_len(42)),
                  stringsAsFactors = FALSE)

# 1. default errors, naming the cell
msg <- tryCatch({ les_aggregate(goods = gid, household = hmap); NULL },
                error = function(e) conditionMessage(e))
stopifnot(!is.null(msg), grepl("x_G <= 0", msg), grepl("BAD", msg))
cat("  ok: default flagged = 'error' stops and names the cell\n")

# 2. keep: algebraic passthrough, flagged
res_k <- withCallingHandlers(
  les_aggregate(goods = gid, household = hmap, flagged = "keep"),
  warning = function(w) {
    stopifnot(grepl("keep", conditionMessage(w)))
    invokeRestart("muffleWarning")
  })
stopifnot(sum(res_k$par$flag_zero) >= 1L,
          any(res_k$par$x <= 0),
          !anyNA(res_k$par$eta))
cat("  ok: keep passes algebraic values with flag_zero = 1\n")

# 3. renormalize: floors, warns, documents the break
res_r <- withCallingHandlers(
  les_aggregate(goods = gid, household = hmap, flagged = "renormalize"),
  warning = function(w) {
    stopifnot(grepl("renormalize", conditionMessage(w)))
    invokeRestart("muffleWarning")
  })
stopifnot(all(res_r$par$x >= 0),
          anyNA(res_r$par$eta),
          is.finite(res_r$audit$addup_break),
          res_r$audit$addup_break > 0)
cat("t05 PASS: error / keep / renormalize behave per AC6 + D-072-03\n")
