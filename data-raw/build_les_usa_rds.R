# build_les_usa_rds.R -- D4 of spec 073: build inst/extdata/les_usa.rds
# (the star schema the lesusa package ships) from the immutable release cut
# frisch_friedman_v1.3.0-tier2 plus the pipeline's canonical demographic
# backbone. Deterministic; verifies every input md5 against MANIFEST.csv
# BEFORE reading; writes nothing except the .rds.
#
# Runs INSIDE the les_usa repo (needs its renv library for data.table); it is
# shipped for provenance and is not installed with the package, so data.table
# never enters the package's declared dependencies (HARr only).
#
#   Rscript release/cge_bridge/data-raw/build_les_usa_rds.R [cut_dir] [out_rds]
#
# Demographics (persons_bar, eqsc_bar): FINLWT21-weighted means of FAM_SIZE
# and the OECD-modified scale eqsc = 1 + 0.5*(pmax(fam-kids,1)-1) + 0.3*kids
# per (state, decile, age) cell, from estimation/inputs/
# cu_group_money_2017_2019.csv (fam, kids, decile10_disp) joined to
# axis_sidecar_2017_2019.csv (state, age5). Cells with no interviewed CUs
# (T3 states, IPF floors) inherit the national (decile, age) profile and are
# flagged demog_src = "national_profile". No raw-CEX re-read.

suppressPackageStartupMessages(library(data.table))

args <- commandArgs(trailingOnly = TRUE)
cut_dir <- if (length(args) >= 1) args[[1]] else
  "release/versions/frisch_friedman_v1.3.0-tier2"
out_rds <- if (length(args) >= 2) args[[2]] else
  "release/cge_bridge/inst/extdata/les_usa.rds"
p_backbone <- "estimation/inputs/cu_group_money_2017_2019.csv"
p_sidecar  <- "estimation/inputs/axis_sidecar_2017_2019.csv"

CUT_FILES <- c(
  cube    = "v0.7_les_fine_42good_state_inc10_age5_2017-2019.csv",
  weights = "v0.7_weight_matrix_state_inc10_age5_2017-2019.csv",
  mass    = "v0.7_cell_mass_state_inc10_age5_2017-2019.csv",
  tier    = "v0.7_state_tier_map.csv",
  ftilt   = "v0.8_fam6_tilt_layer_2017-2019.csv",
  fmarg   = "v0.8_fam6_margins_2017-2019.csv",
  fmass   = "v0.8_cell_mass_state_inc10_age5_fam6_2017-2019.csv")

## ---------------------------------------------------------------- md5 gate --
manifest <- fread(file.path(cut_dir, "MANIFEST.csv"))
for (f in CUT_FILES) {
  want <- manifest[file == f, md5]
  if (length(want) != 1L) stop("MANIFEST.csv has no md5 for ", f)
  got <- unname(tools::md5sum(file.path(cut_dir, f)))
  if (!identical(got, want))
    stop("md5 mismatch for ", f, ": manifest ", want, " vs on-disk ", got,
         " -- refusing to build from a corrupted cut.")
}
cat("md5 gate: ", length(CUT_FILES), " cut files match MANIFEST.csv\n", sep = "")

## ------------------------------------------------------------------- inputs --
cube <- fread(file.path(cut_dir, CUT_FILES["cube"]))
wm   <- fread(file.path(cut_dir, CUT_FILES["weights"]))
mass <- fread(file.path(cut_dir, CUT_FILES["mass"]))
tier <- fread(file.path(cut_dir, CUT_FILES["tier"]))
ftilt <- fread(file.path(cut_dir, CUT_FILES["ftilt"]))
fmarg <- fread(file.path(cut_dir, CUT_FILES["fmarg"]))
fmass <- fread(file.path(cut_dir, CUT_FILES["fmass"]))
stopifnot(nrow(cube) == 107100L, nrow(wm) == 2550L, nrow(mass) == 2550L,
          nrow(tier) == 51L, nrow(ftilt) == 480L, nrow(fmarg) == 30L,
          nrow(fmass) == 15300L)

# Naming-trap normalization at the door (spec D2): cube says age5, companions
# say age -> schema says age; tier map keys plain FIPS -> schema GeoFIPS x1000.
setnames(cube, "age5", "age")
tier[, GeoFIPS := GeoFIPS * 1000L]
stopifnot(all(tier$GeoFIPS %in% unique(cube$GeoFIPS)))

## ---------------------------------------------------------------- cell ids --
cells_key <- unique(cube[, .(GeoFIPS, state, decile, age)])
setorder(cells_key, GeoFIPS, decile, age)
stopifnot(nrow(cells_key) == 2550L)
cells_key[, cell_id := .I]

## --------------------------------------------------------------------- par --
par <- merge(cube[, .(GeoFIPS, decile, age, good, beta, gamma)],
             cells_key[, .(GeoFIPS, decile, age, cell_id)],
             by = c("GeoFIPS", "decile", "age"))
setorder(par, cell_id, good)
par <- par[, .(cell_id, good, beta, gamma)]
stopifnot(nrow(par) == 107100L, !anyNA(par))

## ------------------------------------------------------------------- cells --
cc <- merge(cells_key,
            wm[, .(GeoFIPS, decile, age, N_cu, M_bar, S_c, w_cu, w_exp, w_sup)],
            by = c("GeoFIPS", "decile", "age"))
cc <- merge(cc, mass[, .(GeoFIPS, decile, age, src, share_ipf_state)],
            by = c("GeoFIPS", "decile", "age"))
cc <- merge(cc, unique(cube[, .(GeoFIPS, decile, age, tier, mbar_cell)]),
            by = c("GeoFIPS", "decile", "age"))
stopifnot(nrow(cc) == 2550L, cc[, all(M_bar == mbar_cell)])
cc[, mbar_cell := NULL]

# demographics ---------------------------------------------------------------
bb <- fread(p_backbone,
            select = c("cu", "year", "FINLWT21", "fam", "kids", "decile10_disp"))
sc <- fread(p_sidecar, select = c("cu", "year", "state", "age5"))
bb[, cu := as.character(cu)]; sc[, cu := as.character(cu)]
d <- merge(bb, sc, by = c("cu", "year"), all.x = TRUE)
d[, eqsc := 1 + 0.5 * (pmax(fam - kids, 1L) - 1L) + 0.3 * kids]
nat <- d[!is.na(age5),
         .(persons_nat = weighted.mean(fam,  FINLWT21),
           eqsc_nat    = weighted.mean(eqsc, FINLWT21)),
         by = .(decile = decile10_disp, age = age5)]
dem <- d[!is.na(state) & !is.na(age5),
         .(persons_bar = weighted.mean(fam,  FINLWT21),
           eqsc_bar    = weighted.mean(eqsc, FINLWT21), n_cu_obs = .N),
         by = .(GeoFIPS = state * 1000L, decile = decile10_disp, age = age5)]
cc <- merge(cc, dem, by = c("GeoFIPS", "decile", "age"), all.x = TRUE)
cc <- merge(cc, nat, by = c("decile", "age"), all.x = TRUE)
cc[, demog_src := fifelse(is.na(persons_bar), "national_profile", "cex")]
cc[is.na(persons_bar), `:=`(persons_bar = persons_nat, eqsc_bar = eqsc_nat)]
cc[, c("persons_nat", "eqsc_nat", "n_cu_obs") := NULL]
stopifnot(!anyNA(cc), all(cc$persons_bar > 0), all(cc$eqsc_bar >= 1))
cat(sprintf("demographics: %d cells empirical, %d from national profile\n",
            cc[demog_src == "cex", .N], cc[demog_src != "cex", .N]))
setorder(cc, cell_id)
cells <- cc[, .(cell_id, GeoFIPS, state, decile, age, N_cu, M_bar, S_c,
                w_cu, w_exp, w_sup, tier, src, share_ipf_state,
                persons_bar, eqsc_bar, demog_src)]

## ------------------------------------------------------------------- goods --
HLAB <- c(
  H01_food_home = "Food at home", H02_food_away = "Food away from home",
  H03_housing = "Housing", H04_electricity = "Electricity",
  H05_other_energy_water = "Other energy and water",
  H06_communication = "Communication", H07_hh_operations = "Household operations",
  H08_furnishings = "Furnishings", H09_apparel = "Apparel",
  H10_vehicle_purchases = "Vehicle purchases", H11_motor_fuels = "Motor fuels",
  H12_vehicle_op_transit = "Vehicle operation and transit",
  H13_health_oop = "Health, out-of-pocket", H14_health_insurance = "Health insurance",
  H15_recreation = "Recreation", H16_other_goods_svcs = "Other goods and services")
goods <- unique(cube[, .(good, level, parent)])
setorder(goods, good)
stopifnot(nrow(goods) == 42L, all(goods$parent %in% names(HLAB)))
pretty_stem <- function(g) {
  s <- sub("^[A-Z]\\d+_", "", g)
  s <- gsub("_", " ", s)
  paste0(toupper(substring(s, 1, 1)), substring(s, 2))
}
goods[, label := fifelse(good %in% names(HLAB), unname(HLAB[good]),
                         pretty_stem(good))]

## ------------------------------------------------------------------ states --
st <- tier[, .(GeoFIPS, state, division, region, tier, S_M, se_S_M)]
st <- merge(st, unique(mass[, .(GeoFIPS = GeoFIPS, share_ipf_state)])[
  , .(share_ipf_state = share_ipf_state[1]), by = GeoFIPS], by = "GeoFIPS")
stopifnot(nrow(st) == 51L)

## -------------------------------------------------------------- fam6 layer --
fam_tilts   <- ftilt[order(q, fam6, parent)]
fam_margins <- fmarg[order(q, fam6)]
fam_cells <- merge(fmass[, .(GeoFIPS, decile, age, fam6, N_cu_f, M_bar_f,
                             src, share_ipf_state)],
                   cells_key[, .(GeoFIPS, decile, age, cell_id)],
                   by = c("GeoFIPS", "decile", "age"))
setorder(fam_cells, cell_id, fam6)
fam_cells <- fam_cells[, .(cell_id, fam6, N_cu_f, M_bar_f, src, share_ipf_state)]
stopifnot(nrow(fam_cells) == 15300L)
# collapse check: fam masses must reproduce the v0.7 masses (cut README claim).
# N_cu_f ships at 2 decimals, so six summed rows floor the achievable error at
# ~0.03 ABSOLUTE (CLAUDE.md rule 10: gate against the precision of the FILE,
# not of the computation). A relative 1e-6 gate here is impossible by design.
chk <- merge(fam_cells[, .(N_f = sum(N_cu_f)), by = cell_id],
             cells[, .(cell_id, N_cu)], by = "cell_id")
dev_abs <- chk[, max(abs(N_f - N_cu))]
if (dev_abs > 0.031)
  stop("fam mass collapse deviates by ", dev_abs,
       " (> 2dp file precision floor)")
cat(sprintf("fam mass collapse: max|sum_f N_cu_f - N_cu| = %.4f (2dp floor)\n",
            dev_abs))

## -------------------------------------------------------------------- meta --
meta <- list(
  schema_version = "1.0",
  cut         = basename(normalizePath(cut_dir, winslash = "/")),
  built       = format(Sys.time(), tz = "UTC", usetz = TRUE),
  window      = "2017-2019",
  n_cu_total  = sum(cells$N_cu),
  source_md5  = as.data.frame(manifest[file %in% CUT_FILES]),
  weight_contract = paste(
    "D-072-02: across cells, N and M_bar and gamma aggregate by w_cu",
    "(CU mass); beta aggregates by w_sup (supernumerary mass,",
    "SUP_c = M_bar_c - Gamma_c). Derived quantities (w, eta, eps, S, phi)",
    "are re-derived from the aggregated primitives, never averaged."),
  ras_note = paste(
    "The fam6 layer composes onto the cube by RAS/biproportional fitting",
    "(row margin sum_g beta_f = 1 exact; column margin",
    "sum_f w_fq beta_f = beta to 1e-12). Multiplying the tilt T onto beta",
    "and renormalizing the row does NOT reproduce the composed object",
    "(differences up to 0.165 in absolute beta)."),
  honesty = paste(
    "R2: no standard errors ship on the cube grid; only state-level S_M",
    "carries an SE. R3: 1,781 of 107,100 rows have x_g < 0 at base prices",
    "(negative inherited gamma); coarse aggregation absorbs them but the",
    "count is always reported. R5: ten states are 100% IPF-placed (no CEX",
    "interviews); share_ipf_state reaches the output as a mass-weighted",
    "share. Family layer: calibrated composition from the 30-cell fam6xq5",
    "donor; w_fq is national; cite the donor, never the composed cube."),
  naming = paste(
    "Schema uses `age` (cube's age5 renamed) and GeoFIPS = state FIPS x 1000",
    "everywhere, including the tier map (re-keyed on entry)."),
  citation = paste(
    "Simonato, T. (2026). LES-USA: Stone-Geary parameter database for the",
    "United States, 2017-2019 (frisch_friedman_v1.3.0-tier2). DOI pending."))

## ----------------------------------------------------------- AC4 self-check --
les <- list(par = as.data.frame(par), cells = as.data.frame(cells),
            goods = as.data.frame(goods), states = as.data.frame(st),
            fam_tilts = as.data.frame(fam_tilts),
            fam_margins = as.data.frame(fam_margins),
            fam_cells = as.data.frame(fam_cells), meta = meta)

# round-trip: schema columns must be the source columns, value-identical
rt <- merge(as.data.table(les$par),
            cells_key[, .(GeoFIPS, decile, age, cell_id)], by = "cell_id")
rt <- merge(rt, cube[, .(GeoFIPS, decile, age, good, beta0 = beta,
                         gamma0 = gamma)],
            by = c("GeoFIPS", "decile", "age", "good"))
stopifnot(nrow(rt) == 107100L, rt[, identical(beta, beta0)],
          rt[, identical(gamma, gamma0)])
rt2 <- merge(as.data.table(les$cells),
             wm[, .(GeoFIPS, decile, age, N0 = N_cu, M0 = M_bar, S0 = S_c)],
             by = c("GeoFIPS", "decile", "age"))
stopifnot(nrow(rt2) == 2550L, rt2[, identical(N_cu, N0)],
          rt2[, identical(M_bar, M0)], rt2[, identical(S_c, S0)])
cat("AC4 round-trip: par and cells rebuild the cut columns value-identical\n")

dir.create(dirname(out_rds), showWarnings = FALSE, recursive = TRUE)
saveRDS(les, out_rds, compress = "xz")
cat(sprintf("wrote %s (%.2f MB)\n", out_rds,
            file.size(out_rds) / 1024^2))
