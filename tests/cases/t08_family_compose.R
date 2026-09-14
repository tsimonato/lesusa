# t08 -- the base-R RAS port honours the composer's own contract (specs 074 and
# 077 / compose_cube_v10.R): exact row margin, 1e-12 column recombination,
# admissibility, SUP_MIN floor, mass collapse -- and it is provably NOT the
# forbidden multiply-and-renormalize shortcut (CLAUDE.md rule 7).
#
# beta is the v0.8 construction and its checks are unchanged. gamma is the v1.0
# transport, so check 7 adds what v1.0 buys: x > 0 on all 642,600 composed rows.
les <- les_data()
comp <- compose_fam(les)
stopifnot(nrow(comp$par) == 642600L, nrow(comp$cells) == 15300L)

# 1. row margin exact: sum over 42 goods = 1 per (cell, fam)
rs <- rowsum(comp$par$beta, paste(comp$par$cell_id, comp$par$fam6))
stopifnot(max(abs(rs - 1)) <= 1e-12)

# 2. recombination: sum_f w_fq * beta_f reproduces the cube beta to 1e-12
qs  <- (les$cells$decile + 1L) %/% 2L
q_r <- qs[match(comp$par$cell_id, les$cells$cell_id)]
wfq <- les$fam_margins$w_fq[match(paste(comp$par$fam6, q_r),
                                  paste(les$fam_margins$fam6,
                                        les$fam_margins$q))]
rec <- rowsum(comp$par$beta * wfq, paste(comp$par$cell_id, comp$par$good))
key <- paste(les$par$cell_id, les$par$good)
stopifnot(max(abs(rec[key, 1L] - les$par$beta)) <= 1e-12)

# 3. admissibility + SUP_MIN: beta_f > 0; Gamma_f <= 0.99 * M_bar_f
stopifnot(all(is.finite(comp$par$beta)), all(comp$par$beta > 0))
gam_f <- rowsum(comp$par$gamma, paste(comp$par$cell_id, comp$par$fam6))
mb_f  <- comp$cells$M_bar[match(rownames(gam_f),
                                paste(comp$cells$cell_id, comp$cells$fam6))]
stopifnot(all(gam_f[, 1L] <= 0.99 * mb_f + 1e-6))

# 4. masses collapse back to v0.7 within the 2dp file floor
ncol_f <- rowsum(comp$cells$N_cu, comp$cells$cell_id)
stopifnot(max(abs(ncol_f[as.character(les$cells$cell_id), 1L] -
                  les$cells$N_cu)) <= 0.031)

# 5. NOT multiply-and-renormalize: the naive construction must differ
Tl <- les$fam_tilts
par_p <- les$goods$parent[match(les$par$good, les$goods$good)]
q_p   <- qs[match(les$par$cell_id, les$cells$cell_id)]
f1    <- sort(unique(Tl$fam6))[1L]
T1 <- Tl$T[match(paste(q_p, f1, par_p), paste(Tl$q, Tl$fam6, Tl$parent))]
naive <- les$par$beta * T1
naive <- naive / rowsum(naive, les$par$cell_id)[
  as.character(les$par$cell_id), 1L]
b1 <- comp$par$beta[comp$par$fam6 == f1]
stopifnot(max(abs(b1 - naive)) > 1e-3)

# 6. end to end through the exported function. Through v0.9 at least one
# composed group (e.g. Q4 x F6 x H16) carried a legitimate x_G <= 0 and the
# call had to be made with flagged = "keep". At v1.0 none does, so the same
# call must now come back with nothing flagged at all.
fam_map <- utils::read.csv(corr_file("household_quintile_x_fam6.csv"),
                           comment.char = "#")
# The default call, no opt-out: quintile x fam6 x 16 goods mixes budgets across
# the family axis, which lifted three rows past the ceiling while the band was
# 5; at 4.89 the same partition lands under it.
res <- les_aggregate(
  goods = utils::read.csv(corr_file("goods_42_to_16.csv"),
                          comment.char = "#"),
  household = fam_map, flagged = "keep")
stopifnot(nrow(res$cells) == 30L,
          res$audit$max_dev_addup <= 1e-10,
          res$audit$level_repro_rel <= 1e-10,
          sum(res$par$flag_zero) == 0L, all(res$par$x > 0))

# 7. v1.0 admissibility on the composed object itself
mb_row <- comp$cells$M_bar[match(paste(comp$par$cell_id, comp$par$fam6),
                                 paste(comp$cells$cell_id, comp$cells$fam6))]
gam_row <- gam_f[match(paste(comp$par$cell_id, comp$par$fam6),
                       rownames(gam_f)), 1L]
x_f <- comp$par$gamma + comp$par$beta * (mb_row - gam_row)
stopifnot(length(x_f) == 642600L, all(is.finite(x_f)), all(x_f > 0))
cat(sprintf("  ok: composed family cube has x > 0 in all %d rows (min $%.2f)\n",
            length(x_f), min(x_f)))
cat(sprintf(
  "t08 PASS: RAS port honours the composer contract (max naive-vs-RAS dev %.3f); fam end-to-end 30 groups\n",
  max(abs(b1 - naive))))
