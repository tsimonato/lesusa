# t07 -- AC8: per = "capita" / "adult_equiv" divide levels only. Shares,
# elasticities, S and phi are BIT-identical to the per-CU run.
rdmap <- function(f) utils::read.csv(corr_file(f), comment.char = "#")
g16 <- rdmap("goods_42_to_16.csv")
r4  <- rdmap("regions_51_to_4.csv")
hq  <- rdmap("household_decile_to_quintile.csv")

r_cu <- les_aggregate(goods = g16, regions = r4, household = hq, per = "cu")
r_cap <- les_aggregate(goods = g16, regions = r4, household = hq,
                       per = "capita")
r_ae <- les_aggregate(goods = g16, regions = r4, household = hq,
                      per = "adult_equiv")

for (v in c("beta", "w", "eta", "eps_own", "flag_zero"))
  stopifnot(identical(r_cu$par[[v]], r_cap$par[[v]]),
            identical(r_cu$par[[v]], r_ae$par[[v]]))
for (v in c("S", "phi", "N_cu"))
  stopifnot(identical(r_cu$cells[[v]], r_cap$cells[[v]]),
            identical(r_cu$cells[[v]], r_ae$cells[[v]]))

gI <- match(paste(r_cu$par$REG, r_cu$par$HH),
            paste(r_cu$cells$REG, r_cu$cells$HH))
stopifnot(max(abs(r_cap$par$gamma -
                  r_cu$par$gamma / r_cu$cells$persons_bar[gI])) < 1e-12,
          max(abs(r_ae$par$gamma -
                  r_cu$par$gamma / r_cu$cells$eqsc_bar[gI])) < 1e-12,
          max(abs(r_cap$cells$M_bar -
                  r_cu$cells$M_bar / r_cu$cells$persons_bar)) < 1e-9)
stopifnot(all(r_cu$cells$persons_bar > 1), all(r_cu$cells$eqsc_bar >= 1))
cat("t07 PASS: shares/elasticities bit-identical across per;",
    "levels divided by persons_bar / eqsc_bar\n")
