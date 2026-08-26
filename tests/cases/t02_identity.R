# t02 -- AC3: identity aggregation reproduces the shipped elasticity matrix
# to 1e-8 on all 107,100 rows, INCLUDING the 1,781 flag_zero rows (which is
# why flagged = "keep" exists).
les <- les_data()
if (!dir.exists(CUT_DIR)) {
  cat("t02 SKIP: release cut not found at ", CUT_DIR, "\n", sep = "")
} else {
  em <- utils::read.csv(file.path(
    CUT_DIR, "v0.7_elasticity_matrix_state_inc10_age5_2017-2019.csv"))
  stopifnot(nrow(em) == 107100L)
  gmap <- data.frame(good = les$goods$good, COM = les$goods$good,
                     stringsAsFactors = FALSE)
  hmap <- data.frame(decile = les$cells$decile, age = les$cells$age,
                     state = les$cells$state,
                     HH = paste0("c", les$cells$cell_id),
                     stringsAsFactors = FALSE)
  res <- suppressWarnings(
    les_aggregate(goods = gmap, household = hmap, flagged = "keep"))
  out <- res$par
  stopifnot(nrow(out) == 107100L)
  ci  <- match(out$HH, paste0("c", les$cells$cell_id))
  key_out <- paste(les$cells$GeoFIPS[ci], les$cells$decile[ci],
                   les$cells$age[ci], out$COM)
  j <- match(key_out, paste(em$GeoFIPS, em$decile, em$age, em$good))
  stopifnot(!anyNA(j))
  dev <- c(w   = max(abs(out$w       - em$w_g[j])),
           eta = max(abs(out$eta     - em$eta[j])),
           eps = max(abs(out$eps_own - em$eps_own[j])))
  stopifnot(all(dev <= 1e-8))
  stopifnot(identical(as.integer(out$flag_zero), as.integer(em$flag_zero[j])))
  # cell level: S and phi
  cl <- res$cells
  ci2 <- match(cl$HH, paste0("c", les$cells$cell_id))
  k <- match(paste(les$cells$GeoFIPS[ci2], les$cells$decile[ci2],
                   les$cells$age[ci2]),
             paste(em$GeoFIPS, em$decile, em$age))
  stopifnot(max(abs(cl$S   - em$S_c[k])) <= 1e-8,
            max(abs(cl$phi - em$phi[k])) <= 1e-8)
  cat(sprintf(
    "t02 PASS: identity reproduces the elasticity matrix (max dev w %.1e, eta %.1e, eps %.1e), flag_zero matches %d rows\n",
    dev["w"], dev["eta"], dev["eps"], sum(out$flag_zero)))
}
