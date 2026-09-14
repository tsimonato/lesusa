# t05 -- AC6: the three flagged policies (error / keep / renormalize).
#
# Through v0.9 this test found a native cell carrying an x <= 0 row and drove
# the policies with it. At v1.0 no such cell exists -- that is the whole point
# of spec 077 -- so the test does two things instead: it asserts the shipped
# cube is clean, then builds a fixture with one row pushed below zero on
# purpose and drives the policies with that. The alternative, deleting the
# test, would retire the only coverage the `flagged` argument has, and the
# argument still has to work: a user aggregating to a coarse classification
# can produce x_G <= 0 at the AGGREGATE even when every native row is positive.
les <- les_data()

## 1. the shipped cube is admissible ------------------------------------------
sup <- les$cells$M_bar - rowsum(les$par$gamma, les$par$cell_id)[
  as.character(les$cells$cell_id), 1L]
x_nat <- les$par$gamma + les$par$beta *
  sup[match(les$par$cell_id, les$cells$cell_id)]
stopifnot(length(x_nat) == 107100L, all(is.finite(x_nat)), all(x_nat > 0))
cat(sprintf("  ok: shipped cube has no x <= 0 row (min x = $%.2f)\n",
            min(x_nat)))

## 2. fixture: one good in one cell driven negative ----------------------------
# Lowering gamma_g by d moves x_g by -d*(1 - beta_g) and every other good in
# the cell UP by beta_j*d, so one row crosses zero and the rest stay positive.
# The loader caches the schema, so the fixture is installed in that cache and
# restored on exit -- later test files must see the shipped data, not this.
env   <- environment(les_data)
cache <- get(".les_env", envir = env)
orig  <- cache$les
on.exit(cache$les <- orig, add = TRUE)

bad_cell <- les$cells$cell_id[1L]
rows <- which(les$par$cell_id == bad_cell)
hit  <- rows[which.min(x_nat[rows])]
d    <- (x_nat[hit] + 1) / (1 - les$par$beta[hit])
fx   <- les
fx$par$gamma[hit] <- fx$par$gamma[hit] - d
cache$les <- fx

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

cache$les <- orig
stopifnot(identical(les_data()$par$gamma[hit], orig$par$gamma[hit]))
cat("t05 PASS: error / keep / renormalize behave per AC6 + D-072-03;",
    "shipped cube clean, fixture restored\n")
