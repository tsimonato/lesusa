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
  "release/versions/frisch_friedman_v1.8.0-tier2"
out_rds <- if (length(args) >= 2) args[[2]] else
  "release/cge_bridge/inst/extdata/les_usa.rds"
p_backbone <- "estimation/inputs/cu_group_money_2017_2019.csv"
p_sidecar  <- "estimation/inputs/axis_sidecar_2017_2019.csv"

# The four state x decile x age files move to v1.4 (spec 079, decision
# 2026-09-20): same schema; gamma >= 0 on every row, imposed as a beta cap at
# fixed x with one multiplicative, order-preserving lift of eta (v1.3 imposed
# it on x inside the split and scrambled the state ranking of eta; superseded).
# Lineage below is unchanged. They moved to v1.2 (spec 077) with the same schema,
# admissible by construction on every axis, with eta = beta/w banded at 4.89 on
# every native row, plus the fine regraft (fine expenditure re-closed on the
# observed layer-0 share) and the precision-triggered donor repair (decision
# 2026-09-14; v1.0 banded at 10, v1.1 at 4, both superseded). The band is the
# construction band and 5 is the export ceiling: they are different numbers
# because exact aggregation can exceed its inputs (up to 7.2% here), so 16 of
# the 178 classifications the release sweep drives land above 5 and are refused
# by default rather than returned quietly. The family layer
# is unchanged and still ships under its v0.8 names -- v1.2 changes how it is
# composed, not what it contains. fdonor is new to the cut: the package derives the family logit
# tilt and the RAS seed from it, so it can no longer sit in the repo alone.
CUT_FILES <- c(
  cube    = "v1.4_les_fine_42good_state_inc10_age5_2017-2019.csv",
  weights = "v1.4_weight_matrix_state_inc10_age5_2017-2019.csv",
  mass    = "v1.4_cell_mass_state_inc10_age5_2017-2019.csv",
  tier    = "v1.4_state_tier_map.csv",
  ftilt   = "v0.8_fam6_tilt_layer_2017-2019.csv",
  fmarg   = "v0.8_fam6_margins_2017-2019.csv",
  fmass   = "v0.8_cell_mass_state_inc10_age5_fam6_2017-2019.csv",
  fdonor  = "v0.8_pooled_knownvar_les_fam6xq5_2017-2019.csv")

# Two demographic inputs come from the pipeline, not from the cut, so
# MANIFEST.csv cannot cover them. They are pinned here by md5 instead: without
# this the shipped .rds carried person counts and equivalence scales from
# whatever happened to sit in estimation/inputs, and meta$source_md5 recorded
# no trace of them (codex round 20260826_audit, C2).
EXTRA_INPUTS <- c(
  "estimation/inputs/cu_group_money_2017_2019.csv" =
    "b0e60418a0916191a7cb30d32bd389f2",
  "estimation/inputs/axis_sidecar_2017_2019.csv"   =
    "87ee0d19683c2e38f9af1b6f6941885e")
stopifnot(setequal(names(EXTRA_INPUTS), c(p_backbone, p_sidecar)))

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
extra_md5 <- vapply(names(EXTRA_INPUTS), \(f) {
  got <- unname(tools::md5sum(f))
  if (is.na(got)) stop("missing pipeline input: ", f)
  if (!identical(got, unname(EXTRA_INPUTS[[f]])))
    stop("md5 mismatch for ", f, ": pinned ", EXTRA_INPUTS[[f]],
         " vs on-disk ", got, " -- refusing to build from a drifted input.")
  got
}, character(1))
cat("md5 gate: ", length(CUT_FILES), " cut files match MANIFEST.csv; ",
    length(EXTRA_INPUTS), " pipeline inputs match their pins\n", sep = "")

## ------------------------------------------------------------------- inputs --
cube <- fread(file.path(cut_dir, CUT_FILES["cube"]))
wm   <- fread(file.path(cut_dir, CUT_FILES["weights"]))
mass <- fread(file.path(cut_dir, CUT_FILES["mass"]))
tier <- fread(file.path(cut_dir, CUT_FILES["tier"]))
ftilt <- fread(file.path(cut_dir, CUT_FILES["ftilt"]))
fmarg <- fread(file.path(cut_dir, CUT_FILES["fmarg"]))
fmass <- fread(file.path(cut_dir, CUT_FILES["fmass"]))
fdon  <- fread(file.path(cut_dir, CUT_FILES["fdonor"]))
stopifnot(nrow(cube) == 107100L, nrow(wm) == 2550L, nrow(mass) == 2550L,
          nrow(tier) == 51L, nrow(ftilt) == 480L, nrow(fmarg) == 30L,
          nrow(fmass) == 15300L, nrow(fdon) == 480L)

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

# The v1.0 gamma transport reads two things the tilt layer does not carry: the
# family logit tilt t(q,f) and the RAS seed. Both are functions of the fam6xq5
# donor alone, so they are derived once here rather than shipping the donor's
# raw estimates and re-deriving them at call time. Same algebra as
# R/recover/compose_cube_v10.R -- logit_tilt() is mean-zero under the donor's
# own mass, and the seed is the donor's relative expenditure at its 16 parents.
fdon[, `:=`(fam6 = cell_id %/% 10L, q = cell_id %% 10L)]
fq <- merge(fdon[, .(G = sum(gamma)), by = .(cell_id, fam6, q)],
            unique(fdon[, .(cell_id, n_cu, mbar)]), by = "cell_id")
fq[, S_fq := G / mbar]
stopifnot(all(fq$S_fq > 0), all(fq$S_fq < 1), all(fq$n_cu > 0))
fq[, tilt := {
  l <- qlogis(S_fq); l - sum(n_cu * l) / sum(n_cu)
}, by = q]
fam_logit <- fq[order(q, fam6), .(q, fam6, tilt)]
stopifnot(nrow(fam_logit) == 30L,
          fq[, abs(sum(n_cu * tilt) / sum(n_cu)), by = q][, max(V1)] < 1e-9)

fd2 <- merge(fdon, fq[, .(cell_id, G)], by = "cell_id")
fd2[, x_fq := gamma + beta_pp * (mbar - G)]
xp <- fd2[, .(x_fq = x_fq, parent = good, fam6, q)]
xp <- merge(xp, xp[, .(x_q = mean(x_fq)), by = .(q, parent)],
            by = c("q", "parent"))
xp[, seed_tilt := fifelse(x_fq > 0 & x_q > 0, x_fq / x_q, 1)]
fam_seed <- xp[order(q, fam6, parent), .(q, fam6, parent, seed_tilt)]
stopifnot(nrow(fam_seed) == 480L, all(fam_seed$seed_tilt > 0),
          setequal(fam_seed$parent, unique(fam_tilts$parent)))
cat(sprintf("fam donor: tilt [%.4f, %.4f] | seed_tilt [%.4f, %.4f]\n",
            min(fam_logit$tilt), max(fam_logit$tilt),
            min(fam_seed$seed_tilt), max(fam_seed$seed_tilt)))

## -------------------------------------------------------------------- meta --
meta <- list(
  schema_version = "1.0",
  cut         = basename(normalizePath(cut_dir, winslash = "/")),
  built       = format(Sys.time(), tz = "UTC", usetz = TRUE),
  window      = "2017-2019",
  n_cu_total  = sum(cells$N_cu),
  source_md5  = as.data.frame(manifest[file %in% CUT_FILES]),
  # kept separate from source_md5: these two are pipeline inputs resolved from
  # the repo root, not entries of the release cut, and the package's t01 walks
  # source_md5 relative to CUT_DIR
  pipeline_md5 = data.frame(file = names(extra_md5), md5 = unname(extra_md5),
                            role = c("demographic backbone", "state/age sidecar"),
                            row.names = NULL),
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
    "carries an SE. R3: 0 of 107,100 rows have x_g <= 0 at base prices and",
    "0 of 642,600 rows of the composed family cube do (spec 077: the cube",
    "transports the subsistence share and derives gamma, so x > 0 holds by",
    "construction; through v0.9 it was 1,781 rows). gamma may still be",
    "negative where a good has no subsistence floor -- that is inherited from",
    "the donors and is not an admissibility violation. R4: eta = beta/w is",
    "at most 4.89 on every native row of every axis, by construction",
    "(ETA_MAX). Exports are exact aggregates of those rows, not bounded copies",
    "of them: mixing weightings can push an aggregate above its native inputs",
    "(measured up to 7.2% over the 178 classifications the release sweep",
    "drives), so the construction band does not deliver the export ceiling of",
    "5 (ETA_EXPORT) mechanically: 16 of those 178 exceed it, all merging across",
    "income deciles inside a state (worst g42 x r51 x q_fam6 at 5.24); the CGE",
    "grid stays under at 4.96. What is guaranteed is that none reaches a caller",
    "silently -- les_aggregate() re-checks eta on every row it returns and",
    "refuses above the ceiling by default, so those 16 require an explicit",
    "eta_over = 'warn'/'keep'. R5: ten states are",
    "100% IPF-placed (no CEX",
    "interviews); share_ipf_state reaches the output as a mass-weighted",
    "share. Family layer: calibrated composition from the 30-cell fam6xq5",
    "donor; w_fq is national; cite the donor, never the composed cube."),
  naming = paste(
    "Schema uses `age` (cube's age5 renamed) and GeoFIPS = state FIPS x 1000",
    "everywhere, including the tier map (re-keyed on entry)."),
  citation = paste(
    "Simonato, T. (2026). LES-USA: Stone-Geary parameter database for the",
    "United States, 2017-2019 (frisch_friedman_v1.6.0-tier2). DOI pending."))

## ----------------------------------------------------------- AC4 self-check --
les <- list(par = as.data.frame(par), cells = as.data.frame(cells),
            goods = as.data.frame(goods), states = as.data.frame(st),
            fam_tilts = as.data.frame(fam_tilts),
            fam_margins = as.data.frame(fam_margins),
            fam_cells = as.data.frame(fam_cells),
            fam_logit = as.data.frame(fam_logit),
            fam_seed = as.data.frame(fam_seed), meta = meta)

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
