# t03 -- AC1 (+AC2 on the last one): five partitions, every audit inside
# tolerance. The function itself refuses inconsistent output, so mostly this
# asserts the calls complete and the audits are as tight as claimed.
rdmap <- function(f) utils::read.csv(corr_file(f), comment.char = "#")
g16 <- rdmap("goods_42_to_16.csv")
g2  <- rdmap("goods_42_to_2.csv")
r4  <- rdmap("regions_51_to_4.csv")
r9  <- rdmap("regions_51_to_9.csv")
hq  <- rdmap("household_decile_to_quintile.csv")
ha  <- rdmap("household_age_to_3bands.csv")
hj  <- rdmap("household_quintile_x_age3.csv")
hd  <- data.frame(decile = 1:10, HH = paste0("D", 1:10))

# p5 (the finest partition) legitimately yields 6 output cells with
# x_G <= 0 (H15/H16 in young low-quintile groups): it runs under "keep".
runs <- list(
  p1 = list(goods = g16, regions = r4, household = hq),
  p2 = list(goods = g2,  regions = NULL, household = hd),
  p3 = list(goods = g16, regions = r9, household = ha),
  p4 = list(goods = NULL, regions = NULL, household = NULL),
  p5 = list(goods = g16, regions = r4, household = hj, cross = TRUE,
            flagged = "keep"))

for (nm in names(runs)) {
  a <- runs[[nm]]
  res <- suppressWarnings(les_aggregate(
    goods = a$goods, regions = a$regions, household = a$household,
    flagged = if (is.null(a$flagged)) "error" else a$flagged,
    cross_price = isTRUE(a$cross)))
  au <- res$audit
  stopifnot(au$max_dev_addup <= 1e-10,
            au$max_dev_engel <= 1e-10,
            au$level_repro_rel <= 1e-10,
            all(res$cells$S > 0 & res$cells$S < 1))
  if (isTRUE(a$cross))
    stopifnot(au$max_dev_homogeneity <= 1e-8, au$max_dev_cournot <= 1e-8)
  cat(sprintf(
    "  %s: %d groups x %d goods | addup %.1e | engel %.1e | level %.1e\n",
    nm, nrow(res$cells), length(unique(res$par$COM)), au$max_dev_addup,
    au$max_dev_engel, au$level_repro_rel))
}
cat("t03 PASS: five partitions, all audits inside tolerance",
    "(incl. cross-price identities on p5)\n")
