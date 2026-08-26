# make_correspondences.R -- D5 of spec 073: generate the shipped templates
# and worked examples in inst/correspondence/ from the built rds itself, so
# they can never drift from the data. Deterministic; base R only.
#   Rscript release/cge_bridge/data-raw/make_correspondences.R

pkg <- "release/cge_bridge"
if (!dir.exists(pkg) && file.exists("DESCRIPTION")) pkg <- "."
les <- readRDS(file.path(pkg, "inst/extdata/les_usa.rds"))
outd <- file.path(pkg, "inst/correspondence")
dir.create(outd, showWarnings = FALSE, recursive = TRUE)

wcsv <- function(df, name, comment) {
  path <- file.path(outd, name)
  con <- file(path, "w")
  writeLines(paste("#", comment), con)
  utils::write.csv(df, con, row.names = FALSE, quote = FALSE)
  close(con)
  cat("wrote", path, "\n")
}

## ------------------------------------------------------------- templates --
wcsv(data.frame(good = les$goods$good, COM = "TODO"),
     "goods_template.csv",
     "map each native good (42) to your model commodity; labels [A-Za-z][A-Za-z0-9_]*, max 12 chars")
wcsv(data.frame(state = sort(les$states$state), REG = "TODO"),
     "regions_template.csv",
     "map each state (51) to your model region")
hh_grid <- expand.grid(decile = 1:10, age = 1:5)
wcsv(data.frame(hh_grid, HH = "TODO"),
     "household_template.csv",
     "map each decile x age cell to your household type; may also claim state and/or fam")

## ------------------------------------------------------- worked examples --
# goods 42 -> 16 parents, short GEMPACK-safe codes (H01..H16)
wcsv(data.frame(good = les$goods$good,
                COM  = substr(les$goods$parent, 1, 3)),
     "goods_42_to_16.csv",
     "42 fine goods -> 16 headline parents (H01..H16, see goods table labels)")
# goods 42 -> 2: food (H01 food at home + H02 food away) vs the rest
wcsv(data.frame(good = les$goods$good,
                COM  = ifelse(les$goods$parent %in%
                                c("H01_food_home", "H02_food_away"),
                              "FOOD", "NONFOOD")),
     "goods_42_to_2.csv", "42 goods -> FOOD / NONFOOD")
# regions 51 -> 4 census regions and -> 9 divisions. The states table
# carries region/division as full names; divisions need GEMPACK-safe
# (<= 12 char) codes.
divl <- c("New England"        = "New_England",
          "Middle Atlantic"    = "Mid_Atlantic",
          "East North Central" = "EN_Central",
          "West North Central" = "WN_Central",
          "South Atlantic"     = "S_Atlantic",
          "East South Central" = "ES_Central",
          "West South Central" = "WS_Central",
          "Mountain"           = "Mountain",
          "Pacific"            = "Pacific")
st <- les$states[order(les$states$state), ]
stopifnot(all(st$region %in% c("Northeast", "Midwest", "South", "West")),
          all(st$division %in% names(divl)))
wcsv(data.frame(state = st$state, REG = st$region),
     "regions_51_to_4.csv", "51 states -> 4 census regions")
wcsv(data.frame(state = st$state, REG = unname(divl[st$division])),
     "regions_51_to_9.csv", "51 states -> 9 census divisions")
# household: deciles -> quintiles; age -> 3 bands; joint
wcsv(data.frame(decile = 1:10, HH = paste0("Q", rep(1:5, each = 2))),
     "household_decile_to_quintile.csv", "10 deciles -> 5 quintiles")
band <- c("Young", "Midlife", "Midlife", "Senior", "Senior")
wcsv(data.frame(age = 1:5, HH = band),
     "household_age_to_3bands.csv",
     "age5 -> Young(<35) / Midlife(35-54) / Senior(55+)")
jg <- expand.grid(decile = 1:10, age = 1:5)
wcsv(data.frame(jg, HH = paste0("Q", rep(1:5, each = 2)[jg$decile], "_",
                                band[jg$age])),
     "household_quintile_x_age3.csv", "joint: 5 quintiles x 3 age bands")
# household with fam: quintile x fam6 (F1..F6 in level order; original labels
# in the comment so nobody has to guess)
fam_lv <- sort(unique(les$fam_margins$fam6))
fg <- expand.grid(decile = 1:10, age = 1:5, fam = fam_lv,
                  stringsAsFactors = FALSE)
fcode <- paste0("F", match(fg$fam, fam_lv))
wcsv(data.frame(fg, HH = paste0("Q", rep(1:5, each = 2)[fg$decile], "_",
                                fcode)),
     "household_quintile_x_fam6.csv",
     paste("claims fam -> composes v0.8 at call time (see README caveats);",
           "F1..F6 =", paste(fam_lv, collapse = ", ")))
cat("done\n")
