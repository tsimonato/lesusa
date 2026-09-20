# lesusa 0.5.0 (2026-09-20)

New data. The package ships the `frisch_friedman_v1.8.0-tier2` cut (cube v1.4),
which supersedes the v1.7.0-tier2 cut (cube v1.3) that 0.4.0 shipped.
**Parameter values change**: `les_aggregate()` does not return what 0.4.0
returned. If you built a model on 0.4.0 output, rerun it from the parameter
build onwards. No estimation was re-run; the Stata NLSUR donors, the national
decile donor, the tier map and the cell-mass matrix are unchanged
(byte-identical to 0.4.0).

- **What was wrong with 0.4.0.** `gamma >= 0` was imposed as a lower bound on
  expenditure *inside* the biproportional split (`x >= beta*SUP`). That moved
  the split, not the parameter: the column targets were lifted above the
  observed SAPCE margin and the cube stopped reproducing the shares it is built
  to reproduce (vehicle purchases at 34% of the top-decile budget against 2%
  observed; closure error 2.1e-2 where v1.2 had 1e-15). Because the lift was
  order-blind, household operations -- income elasticity 0.89 at the donor --
  was pushed to `gamma = 0` in 772 cells with an elasticity of up to 2.37, a
  number that carries no preference at all, and the state ranking of its
  elasticity was redrawn from one decile to the next (Spearman rho 0.14 between
  adjacent deciles). A sweep of the shipped output for anomalies found it
  (`tests/test_export_heterogeneity.R`, gate H4a); that sweep is now a release
  gate and 0.4.0 fails it.
- **The rule that replaces it.** Expenditure is held at the transported share
  and the floor goes on the marginal budget share: in every cell
  `beta_g <= x_g / SUP`, and the mass the capped goods give up is placed by
  **one multiplicative lift of every good's income elasticity, clipped at the
  common ceiling** -- `eta_new = min(mbar/SUP, lambda * eta)`, `lambda >= 1`
  the unique root of adding-up. The ceiling is the same for every good in a
  cell, so the map preserves the within-cell ranking of goods by elasticity: a
  necessity is never lifted above a luxury, no free good's elasticity falls, a
  capped good sits exactly at the LES bound. Every RAS margin closes as it did
  on v1.2; the parent's subsistence total is reproduced up to the cap identity,
  which the gates close on exactly and the cut ships per row
  (`v1.4_gamma_floor_cap_*.csv`). Two intermediate rules were tried and
  rejected on the way -- lifting only the luxuries' excess with a fallback that
  turned out to fire in 586 of 2,550 cells, and the 0.4.0 rule itself; the
  decision log has both with their measurements.
- **What it costs, stated plainly.** The LES identity is unchanged:
  `gamma_c >= 0 <=> eta_c <= mbar / SUP`, so the top deciles still see the
  ceiling (maximum `eta` 1.42-1.66 in deciles 7-10). What changes is *who* pays:
  the whole profile compresses toward the ceiling from below (food 0.45 ->
  ~0.55 in a top decile where `lambda ~ 1.2`) instead of a few necessities
  being pushed to zero subsistence. 9,917 of 107,100 base rows (9.3%) sit at
  the floor with `eps_own = -1` (0.4.0: 15,213, 14.2%). The weakest
  state-ranking stability of any good across deciles is rho 0.54 (0.4.0:
  0.14). Committed expenditure per cell is unchanged to $0.02.
- **The package composer is corrected too.** `les_aggregate()` composes the
  family axis itself (`compose_fam.R`), and 0.4.0 had wired the x-bound into
  that RAS as well. On a v1.4 cube that fit does not settle (321 passes), which
  is how the second copy was caught. The composer now carries the same beta
  cap at fixed x as the reference implementation (`cap_beta_gamma_floor`,
  ported verbatim), so the family cube the package returns is the one the cut's
  `verify_companions.R` reproduces (V15 closes on the cap identity at 7.7e-13).
- **Exports.** Over the 178-granularity release sweep **no listed
  classification exports above the ceiling of 5** (0.4.0: 4; 0.3.0: 16); the
  worst is 4.96 at `g16 x usa x dec_st`, the TERM export granularity. The
  adversarial two-cell merge still reaches 5.47 on `R04_other_recreation` and
  is still refused by default. `ETA_EXPORT` stays 5; the `gamma >= 0` hard
  check on every returned row stays, with no opt-out.
- **Reproducibility.** Cube v1.3 is not deleted: `LES_CUBE_VERSION=v1.3`
  regenerates the v1.7.0-tier2 files byte for byte from the same code
  (`gamma_rule_for("v1.3") == "x"`), so the 0.4.0 numbers remain a checkable
  record rather than a memory.

# lesusa 0.4.0 (2026-09-18)

New data. The package ships the `frisch_friedman_v1.7.0-tier2` cut (cube v1.3),
which supersedes the v1.6.0-tier2 cut (cube v1.2) that 0.3.0 shipped.
**Parameter values change**: `les_aggregate()` does not return what 0.3.0
returned. If you built a model on 0.3.0 output, rerun it. No estimation was
re-run; the Stata NLSUR donors, the tier map and the cell-mass matrix are
unchanged.

- **Subsistence is non-negative everywhere, by construction.** `gamma >= 0` now
  holds on every one of the 642,600 native rows and on every output cell of
  every granularity `les_aggregate()` can express. In 0.3.0 it did not: 10,824
  of 107,100 rows (10.1%) carried `gamma < 0`, and a downstream GTAP/TERM graft
  rejected the export because its demand system requires a non-negative
  subsistence quantity per household and commodity. The 0.2.0/0.3.0 notes called
  that "not an admissibility violation". For Stone-Geary as a utility function
  that was defensible — only `x > gamma` is required — but the wording hid a
  real constraint on consumers and is withdrawn.
- **Where the negatives came from.** Not from the estimator: the NLSUR
  parametrises subsistence in logs, so its estimate cannot be negative. Within a
  cell prices are fixed, so the *levels* of `gamma` are not identified; what is
  identified is the intercept `a_j = gamma_j - beta_j * Gamma`. The recovery step
  therefore keeps `a` and re-anchors the level on the calibrated Frisch total
  `G = mbar(1 + 1/omega)` as `gamma = a + beta * G`. That rule has no boundary,
  and where `G` falls below the estimator's own subsistence sum a luxury with a
  small intercept and a large `beta` is pushed through zero.
- **The rule that replaces it.** On the identified ray the only point with
  `sum gamma = G` is that same vector, so non-negativity and the calibrated `G`
  cannot both hold on the ray: any fix leaves it. Of the two candidates
  implemented and measured, the beta-weighted projection drags 26 goods with
  *positive* subsistence to zero (apparel, health out-of-pocket, household
  operations among them) and was rejected; the shipped rule zeros the negative
  goods and rescales the rest by one common factor, which sends exactly 0
  positive goods to zero. `beta`, budget shares, `eta`, `omega`, `S`, `M_bar`
  and the Frisch profile are untouched; only the composition of `gamma` moves,
  and with it `eps_own`. A good at the floor carries `eps_own = -1` exactly.
- **What it costs, stated plainly.** In the LES, `gamma_c >= 0` is the same
  inequality as `eta_c <= M_bar / SUP`: no good may respond to income more
  strongly than the cell's own Frisch parameter. That ceiling binds hardest
  where the supernumerary share is largest, so the top deciles lose the most.
  Maximum `eta` by decile falls from 4.89 across the board to 4.89 (decile 1,
  where the bound is 3.85) and to 1.42-1.66 in deciles 7-10. Across states
  within a (decile, good), the standard deviation of `gamma` falls to 57% of
  v1.2 and of `eta` to 77%. 15,213 of 107,100 rows (14.2%) sit at the floor.
  Committed expenditure per cell is unchanged to $0.02.
- **Fewer classifications need `eta_over`.** Over the 178-granularity release
  sweep, those exporting above the ceiling of 5 fall from **16 to 4** (max 5.47
  at `g42 x r51 x q_age3`, then 5.17, 5.01, 5.01), because the native income
  elasticities themselves came down. The aggregation overshoot over the native
  band moves the other way, 7.2% to 11.9%: exact aggregation weights `beta` by
  supernumerary mass and `x` by CU mass, and the floor lowers `SUP` where it
  binds, which widens the gap. `ETA_EXPORT` stays 5 and the default still
  refuses, so nothing above it reaches a caller silently.
- **A new hard check.** `les_aggregate()` re-checks `gamma >= 0` on every row it
  returns and stops, naming the rows, if any is negative. There is no opt-out:
  unlike `eta_over`, this is not a plausibility band but an admissibility
  condition. It caught a real defect during development — the family axis is
  composed inside this package, and its composer still carried the old bound.

# lesusa 0.3.0 (2026-09-14)

New data. The package now ships the `frisch_friedman_v1.6.0-tier2` cut (cube
v1.2), which supersedes the v1.5.0-tier2 cut (cube v1.1) that 0.2.0 shipped.
**Parameter values change**: `les_aggregate()` does not return what 0.2.0
returned. If you built a model on 0.2.0 output, rerun it. No estimation was
re-run; the Stata NLSUR donors are the same, and the tier map and cell-mass
matrix are byte-identical.

- **Why.** Sweeping the aggregations a CGE user can request against the v1.1
  cube found three plausibility defects that every admissibility gate had
  passed. (1) The v1.1 donor cap spread recreation's excess marginal share in
  proportion to budget shares, which adds the same constant (+0.52) to every
  other group's eta in decile 2 and left food at 0.62 against neighbours of
  0.39 and 0.44; the decile axis carried donor noise, not an Engel gradient.
  (2) The band of 4 clipped a precisely estimated plateau: vehicle purchases
  sits at eta 3.8 to 4.7 in decile 1 and deciles 3 to 9 (t from 4.8 to 13.0),
  4,463 native rows sat at exactly 4.000 in 70% of cells, and the dispersion
  of its eta across the 51 states fell from 0.245 to 0.109. (3) At the fine
  42-good level, beef, pork, other meat, poultry, seafood and eggs together
  came to $39 a year in decile 2 (0.13% of a $29,417 budget) against $1,260
  in decile 8.
- **Donor repair, by precision.** A national decile cell is flagged when its
  standard error is 4 times the median standard error of the same group
  across the ten deciles (`C_PRECISION`); the ratio over the 160 group cells
  runs 8.04, 6.20, then 3.53, so any constant in (3.53, 6.20] picks the same
  two cells, and a precisely estimated cell is never touched however high it
  sits. The flagged cell takes the running median of three of its own income
  profile and the other groups of that decile are rescaled by one common
  factor (multiplicative replacement, Martin-Fernandez, Barcelo-Vidal and
  Pawlowsky-Glahn 2003). Two of 160 cells moved: recreation in decile 2 (eta
  10.63 to 1.79) and decile 4 (5.00 to 2.83). `x` and `w` are untouched;
  `sum beta` and `sum gamma` hold at file precision.
- **Fine graft closed on the observed share.** Fine expenditure is now
  `x_item = x_G * s_i` with `s_i` the Diary layer-0 share (protein share of
  food 0.225 to 0.210 across deciles, se at most 0.012), `beta_item`
  unchanged and `gamma_item = x_item - beta_item * SUP`. Within each parent
  the sums of `x`, `beta` and `gamma` are preserved exactly, so nothing
  above the fine level moves through this change. Only the 18 food items are
  affected; 213 of 290 fine rows moved; the smallest fine expenditure rises
  from $2.56 to $32.83 a year and fine eta max falls from 13.20 to 4.70.
- **Native band 4.89, export ceiling 5.** The band on native rows moves from
  4 to 4.89 (`ETA_BAND_V12`), which clips nothing at the repaired donor
  (maximum 4.70) and pins 1,052 rows against 998 before. The band still
  binds on `x`, never on `beta`. The export ceiling stays at 5.
- **Export behaviour above 5.** `les_aggregate()` still recomputes eta on
  every row it returns and, by default (`eta_over = "error"`), stops before
  returning or writing anything, naming the rows, when any exceeds 5;
  `"warn"` and `"keep"` opt in. What changed is how often the default fires.
  Exact aggregation weights `beta` by supernumerary mass and `x` by CU mass,
  so a merged group's eta can exceed every row it merges; over the 178
  listed classifications the excess now reaches 7.2% (down from 12.8% before
  the donor repair), and **16 of the 178 export above 5** (5.24, 5.21, 5.18,
  5.18, 5.18, 5.06 and on), all of them merging income deciles inside a
  state. Those 16 need `eta_over = "warn"` or `"keep"`. The 16-good x
  51-state x 10-decile grid the TERM pipeline reads stays under, at 4.96.
- **Correction to the 0.2.0 entry below.** It says the export sweep "gates
  eta at 5 on all of them (worst 4.51; 4.11 at the TERM export)" and that
  "the shipped correspondences never trigger" the default stop. Both were
  true of the v1.1 cube at a band of 4 and are no longer true: see the
  previous item. A band that would keep all 178 under 5 is 4.66, below the
  repaired donor's maximum, and was refused because it would clip the
  vehicle plateau again.
- **Measured on the shipped v1.2 files** (`tests/test_cube_v10_gates.R`, all
  PASS): `x > 0` and `eps_own < 0` everywhere; eta max 4.8905 on the
  107,100-row base cube and 4.8900 on the 642,600 composed family rows, 0
  rows above the band; no cell on the 1% supernumerary floor; adding-up to
  1.55e-15 (base) and 4.44e-16 (family). The age layer's CU-weighted gamma
  reproduces the parent on 19,663 of 21,420 (cell, good) pairs; the 1,757
  that differ do so by a median of $1.13 and at most $1,090.95 (1.61% of
  that cell's budget).
- **New gate.** `tests/test_export_heterogeneity.R` in the repo carries
  fifteen assertions in six families (income profile against neighbouring
  deciles, band occupancy, across-state dispersion, rank stability of the
  state ordering, fine expenditure levels, Engel shape and subsistence
  profile). It fails six on the v1.1 cube and passes 15 of 15 on v1.2.
- **Still open, recorded rather than repaired.** The decile axis rests on
  estimates whose split-half replication failed in deciles 1, 2, 3 and 10;
  the repair treats the two cells where that produced an implausible level,
  not the instability itself. The CU-weighted subsistence share rises
  between deciles 7 and 9 (0.180, 0.183, 0.189), inside the gated tolerance.

# lesusa 0.2.0 (2026-09-13)

New data. The package now ships the `frisch_friedman_v1.5.0-tier2` cut (cube
v1.1), whose cube is LES-admissible by construction on every axis (spec 077).
**Parameter values change**: `les_aggregate()` does not return what 0.1.1
returned.

- Revised 2026-09-13, before publication, twice. First, the cut gained an
  **eta band**: `x > 0` left `eta = beta/w` unbounded, and the first build
  reached eta = 2,328 on native rows and 84 at the 16 x 51 x 10 export; a
  band of 10 was imposed on `x` inside the biproportional split (a column
  floor and a per-child lower bound). Second, the same day, the band moved to
  **4 on every native row** and the ceiling on every export to **5**, after
  the PI asked why a plausibility test had passed an export with eta 10.08.
  The cause sat upstream of the splits: the national decile LES that seeds
  them gives recreation a marginal budget share of 0.78 in decile 2 on an
  average share of 0.07 (eta 10.6). The band is now applied in two places:
  on that donor, where it binds on `beta` (19 of 420 rows capped; the excess
  is reallocated across the decile in proportion to budget shares and gamma
  is re-derived with fitted expenditure unchanged), and on every split below,
  where it binds on `x`, never on `beta`. `compose_fam()` carries the same
  bounded split, so the composed family rows hold the band too. The native
  band sits a fifth under the export ceiling because an aggregate weights
  beta by supernumerary mass and x by CU mass and can land up to 13% above
  the rows it merges. The repo's export sweep
  (`tests/test_export_admissibility.R`) drives `les_aggregate()` over 178
  classifications, the shipped correspondences and the identity and
  intermediate maps built from the cube's own keys, and gates eta at 5 on
  all of them (worst 4.51; 4.11 at the TERM export).
- **`les_aggregate()` checks the export band on every call.** A finite sweep
  cannot cover every partition a user can write, and the external review of
  2026-09-13 found one that breaks it: merging two native cells whose budgets
  differ by an order of magnitude (Louisiana d1 a1 with Wyoming d2 a5) puts
  `R04_other_recreation` at eta = 16.9 under the band of 10 (6.2 under the
  band of 4), an exact aggregate of two admissible rows. The function now
  recomputes eta on every row it returns and, by default, **stops** before
  returning or writing anything, naming the worst rows, when any exceeds 5;
  `eta_over = "warn"` or `"keep"` opts into the exact aggregates with a
  warning or silently; `audit$n_eta_above` and
  `audit$eta_max` carry the count and the maximum. Values are returned
  untouched. The shipped correspondences never trigger it.
- **Bounded RAS gains a fallback.** The active-set loop in `ras_split()` pins
  entries at their bound and never releases them, which can leave a feasible
  transport unsolvable (a 2 x 2 counterexample from the same review). When the
  loop cannot settle, the split is now solved as `lower + v` with `v` fitted to
  the residual margins, which is exact whenever the bounds are feasible. It is
  a fallback only: the shipped cube and every composed family row are
  byte-identical to what the active-set loop produced.

- Through v0.9 the cube carried `gamma` as a primitive and derived expenditure
  as `x = gamma + beta*SUP`. Nothing forced `x > 0`, so 1,781 of 107,100 rows
  shipped with `x_g <= 0`, where the budget share turns non-positive, the
  income elasticity explodes and the own-price elasticity goes positive. v1.0
  inverts the parametrisation: it transports the subsistence **share** through
  a logit level plus a biproportional split across goods, and **derives**
  `gamma = x - beta*SUP`. `x > 0` and `eps_own < 0` now hold by construction.
- The count is **0 of 107,100** native rows and **0 of 642,600** composed
  family rows. `flag_zero` is retained, and is all zeros.
- `meta$honesty` is corrected. It previously said coarse aggregation absorbed
  the flagged rows; an audit disproved that (3.1% reached the exported file).
  The sentence now reports the measured zero.
- `compose_fam()` gains the v1.0 gamma transport. `beta` is unchanged — still
  the v0.8 RAS against the `w_fq` family margin — so only `gamma` moves. The
  composed cube matches the reference composer `compose_cube_v10.R` to 5e-11,
  against a 4-decimal file precision.
- Two new tables in the shipped schema, `fam_logit` and `fam_seed`, carry the
  family logit tilt and the RAS seed derived from the `fam6xq5` donor. The
  donor itself now ships inside the release cut, so the layer is re-derivable
  by anyone holding the cut.
- `stats` is a declared import (`plogis`, `qlogis`, `uniroot`).
- Test suite: `t05` no longer hunts for a native `x <= 0` row, because none
  exists; it asserts the shipped cube is clean and drives the three `flagged`
  policies from a deliberate fixture instead. `t08` gains a check that all
  642,600 composed rows have `x > 0`.

# lesusa 0.1.1 (2026-08-26)

Provenance fix. The parameters are unchanged: `les_aggregate()` returns exactly
what 0.1.0 returned, bit for bit.

- The build script now pins the two demographic inputs it reads from the
  pipeline rather than from the release cut, `cu_group_money_2017_2019.csv` and
  `axis_sidecar_2017_2019.csv`. They sit outside `MANIFEST.csv`, so the md5 gate
  did not cover them and the shipped data recorded no trace of which version had
  supplied the per-cell person counts and equivalence scales. The build now
  refuses to run if either has drifted.
- Their checksums ride in the new `les_data()$meta$pipeline_md5`, kept separate
  from `meta$source_md5` because the latter resolves against the release cut and
  these two do not.

# lesusa 0.1.0 (2026-08-26)

Initial release.

- Star-schema data: `frisch_friedman_v1.3.0-tier2` cut (v0.7 cube, masses,
  weights, tier map, v0.8 fam6 layer) plus per-cell demographics from the
  pipeline's canonical backbone.
- `les_aggregate()`: exact base-point aggregation over goods, regions and
  household types; closed-form re-derivation of shares and elasticities;
  self-auditing (adding-up, Engel, homogeneity, Cournot, level
  reproduction); GEMPACK `.har` and CSV writers.
- Opt-in family axis via RAS composition of the v0.8 layer.
- `flagged` policies: `error` (default) / `keep` / `renormalize`.
- Tests t01-t08 cover AC1-AC8 of spec 073.
