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
