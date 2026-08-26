# t01 -- AC4: the schema loses nothing. Source md5s still match what the rds
# recorded at build time, and beta/gamma rebuild the cube value-identical.
les <- les_data()
if (!dir.exists(CUT_DIR)) {
  cat("t01 SKIP: release cut not found at ", CUT_DIR, "\n", sep = "")
} else {
  m <- les$meta$source_md5
  for (i in seq_len(nrow(m))) {
    got <- unname(tools::md5sum(file.path(CUT_DIR, m$file[i])))
    if (!identical(got, m$md5[i]))
      stop("md5 drift for ", m$file[i], ": rds says ", m$md5[i],
           ", cut has ", got)
  }
  cube <- utils::read.csv(file.path(
    CUT_DIR, "v0.7_les_fine_42good_state_inc10_age5_2017-2019.csv"))
  stopifnot(nrow(cube) == 107100L)
  cid <- les$cells$cell_id[match(
    paste(cube$GeoFIPS, cube$decile, cube$age5),
    paste(les$cells$GeoFIPS, les$cells$decile, les$cells$age))]
  stopifnot(!anyNA(cid))
  j <- match(paste(cid, cube$good), paste(les$par$cell_id, les$par$good))
  stopifnot(!anyNA(j),
            identical(les$par$beta[j],  cube$beta),
            identical(les$par$gamma[j], cube$gamma))
  # cells side: N_cu, M_bar, S_c value-identical to the weight matrix
  wm <- utils::read.csv(file.path(
    CUT_DIR, "v0.7_weight_matrix_state_inc10_age5_2017-2019.csv"))
  k <- match(paste(wm$GeoFIPS, wm$decile, wm$age),
             paste(les$cells$GeoFIPS, les$cells$decile, les$cells$age))
  stopifnot(!anyNA(k),
            identical(les$cells$N_cu[k],  wm$N_cu),
            identical(les$cells$M_bar[k], wm$M_bar),
            identical(les$cells$S_c[k],   wm$S_c))
  cat("t01 PASS: 7 md5s match; par and cells rebuild the cut",
      "value-identical\n")
}
