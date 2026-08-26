# t04 -- AC5: bad correspondences fail loudly, naming offenders; nothing is
# silently renormalised.
les <- les_data()
expect_error <- function(expr, pattern, what) {
  msg <- tryCatch({ expr; NULL }, error = function(e) conditionMessage(e))
  if (is.null(msg)) stop("expected an error (", what, "), got none")
  if (!grepl(pattern, msg))
    stop("wrong error for ", what, ": ", msg)
  cat("  ok: ", what, "\n", sep = "")
}

g_ok <- data.frame(good = les$goods$good, COM = substr(les$goods$parent, 1, 3))

# 1. unmapped native element (drop one good)
expect_error(
  les_aggregate(goods = g_ok[-1L, ]),
  "unmapped", "unmapped good errors and names it")
# 2. native element mapped twice
expect_error(
  les_aggregate(goods = rbind(g_ok,
                              data.frame(good = g_ok$good[1L], COM = "ZZZ"))),
  "more than one output", "duplicate mapping errors")
# 3. same native dimension claimed by two maps
expect_error(
  les_aggregate(regions = data.frame(state = les$states$state, REG = "USA"),
                household = data.frame(decile = 1:10, age = 1:5,
                                       state = les$states$state[1L],
                                       HH = "H1")[0, ]),
  "claimed by more than one map", "double-claimed `state` errors")
# 4. more than one output column
expect_error(
  les_aggregate(goods = cbind(g_ok, extra = "x")),
  "exactly one output column", "ambiguous output column errors")
# 5. per != cu with a fam-claiming household map is refused
fam_map <- utils::read.csv(corr_file("household_quintile_x_fam6.csv"),
                           comment.char = "#")
expect_error(
  les_aggregate(household = fam_map, per = "capita"),
  "fake precision", "per=capita with fam claim refused")
cat("t04 PASS: five failure modes error with named offenders\n")
