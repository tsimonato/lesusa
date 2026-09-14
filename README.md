# lesusa

Stone-Geary (LES) demand parameters for the United States, 2017-2019, with
one aggregation function that is exact at the base point.

The package ships the `frisch_friedman_v1.5.0-tier2` release of the LES-USA
parameter database: 51 states x 10 income deciles x 5 age groups (2,550
cells), 42 goods per cell, plus cell masses, an optional family-formation
layer, and per-cell demographics. `les_aggregate()` maps that grid to *your*
model's goods, regions and household types.

## Installation

```r
# install.packages("remotes")
remotes::install_github("tsimonato/lesusa")
```

The package has no compiled code and no hard dependencies beyond base R
(R >= 4.1). Writing `.har` files for GEMPACK models needs no extra
software; the writer is internal.

## What is guaranteed

- **Exact at the base point.** The aggregated LES reproduces aggregate demand
  of the disaggregated system with no approximation error: subsistence gamma
  and mean outlay aggregate by CU mass, marginal shares beta by supernumerary
  mass. Adding-up, Engel aggregation, homogeneity and Cournot hold by
  construction; every call audits them (1e-10) and refuses to return an
  inconsistent result.
- **Derived quantities are re-derived, never averaged.** Budget shares,
  income and price elasticities and the Frisch parameter come from the LES
  closed forms evaluated at the aggregated parameters.
- **Nothing silent.** Incomplete or ambiguous correspondences are errors that
  name the offending elements. Illegal GEMPACK names are rejected, not
  renamed.

## What is NOT preserved (read before using)

- **Behaviour away from the base point.** Aggregation is exact at base prices
  and outlays; away from the point, the aggregate LES is an approximation
  like any representative-consumer construction.
- **Standard errors.** The cube grid carries none; only the state-level
  subsistence share `S_M` has an SE (in the `states` table). Do not attach
  inferential language to aggregated parameters.
- **Every native row has x_g > 0.** Through v0.9 the cube derived expenditure
  from a primitive gamma and 1,781 of 107,100 rows came out non-positive; the
  claim made here then, that coarse aggregation absorbs them, was wrong — an
  audit found 3.1% reaching the exported file. The v1.0 cube transports the
  subsistence share and derives gamma, so the count is now **0 of 107,100**,
  and 0 of the 642,600 composed family rows. `n_neg_absorbed` still reports it.
  Exact aggregation of positive native rows keeps every output x_G positive;
  `flagged` (below) only matters for alternative or invalid inputs.
- **Every native row has eta = beta/w <= 4.89 by construction; exports are
  exact aggregates of those rows, and anything above 5 is refused rather than
  returned quietly.** Those are two different promises, and the difference is
  not a hedge. `x > 0` makes eta positive but not bounded: an early v1.0 build
  carried eta up to 2,328 on rows whose expenditure had collapsed to ~1% of the
  parent cell's, and the band of 10 that fixed it still let the national decile
  donor's own outlier through (recreation in decile 2 at eta 10.6, a marginal
  budget share of 0.78 on an average share of 0.07). v1.1 clamped that donor at
  the band, which cured the symptom and moved the excess onto the other goods:
  it quintupled the income elasticity of food in decile 2 and flattened a
  precisely estimated vehicle plateau. v1.2 repairs the donor at the source
  instead, so the band is left with one job — stopping `x` from collapsing
  inside the state, age and family splits — and binds on `x`, never on `beta`.
  Exports are then exact aggregates, not bounded copies: aggregation weights
  beta by supernumerary mass and x by CU mass, so where a luxury's share rises
  with the budget across the merged cells the aggregate can carry a higher eta
  than any row it merges. On this cube that excess reaches **7.2%**, which is
  why 4.89 does not mechanically deliver 5. The repo's sweep
  (`tests/test_export_admissibility.R`) drives 178 classifications — the
  shipped correspondences plus the identity and intermediate maps built from
  the cube's own keys — and **16 of them exceed 5**, all merging across income
  deciles inside a state; the worst is `g42 x r51 x q_fam6` at 5.24, followed
  by `g16 x r51 x q_fam6` (5.21), `g16` and `g42` x `r51` x `age5` / `age3`
  (5.18) and `g42 x r51 x dec_fam6` (5.06). The CGE grid that `usa-ia` reads,
  16 goods x 51 states x 10 deciles, stays under at **4.96**. A two-cell merge
  of very different budgets can go further still. So the guarantee is about
  what reaches you, not about what exists: `les_aggregate()` recomputes eta on
  every row it returns and, by default, **stops** before returning or writing
  anything, naming the worst rows, when any exceeds 5. To obtain one of those
  16 classifications you must ask for it — `eta_over = "warn"` returns the
  exact aggregates with a warning, `eta_over = "keep"` returns them silently —
  and in every mode the count and maximum are in `audit$n_eta_above` and
  `audit$eta_max`. Values are never altered. Coarsen or split the map
  differently, or opt in knowingly.
- **gamma can still be negative** on a good with no subsistence floor. That is
  inherited from the donors and is not an admissibility violation: LES needs
  x > 0 and a positive supernumerary budget, and both hold everywhere.
- **Ten states have no CEX interviews.** Their cells are IPF-placed;
  `share_ipf` reaches the output as a mass-weighted share. Treat
  high-`share_ipf` groups as model-based, not survey-based.
- **The family axis is a calibrated composition** (see below), not an
  estimated dimension.

## Quickstart

```r
library(lesusa)

# built-in worked examples (see inst/correspondence/)
cdir <- system.file("correspondence", package = "lesusa")
g16  <- read.csv(file.path(cdir, "goods_42_to_16.csv"),  comment.char = "#")
r4   <- read.csv(file.path(cdir, "regions_51_to_4.csv"), comment.char = "#")
hq   <- read.csv(file.path(cdir, "household_decile_to_quintile.csv"),
                 comment.char = "#")

res <- les_aggregate(goods = g16, regions = r4, household = hq,
                     file = "les_16x4x5", cross_price = TRUE)
str(res$audit)   # the proof the call is consistent
```

This writes `les_16x4x5.har` (GEMPACK: headers `BETA`, `GAMM`, `XEXP`,
`WSHR`, `ETA`, `EOWN` over COM x REG x HH; `FRSC`, `SUBS`, `MEXP`, `NCU`
over REG x HH; `ECRS` for cross-price) plus `les_16x4x5.csv` and
`les_16x4x5_cells.csv`. The `.har` stores 4-byte reals; exact values live in
the CSVs.

## Correspondences

A map is a CSV (or data.frame): native key column(s) plus one output column.

| argument | native keys | output |
|---|---|---|
| `goods` | `good` (42 codes) | `COM` |
| `regions` | `state` (51 names) | `REG` |
| `household` | `decile`, `age`, optionally `state`, optionally `fam` | `HH` |

A missing map collapses its dimension to one element. Every native element
must map exactly once; `state` can be claimed by `regions` or `household`,
not both. Output labels must be GEMPACK-legal (`[A-Za-z][A-Za-z0-9_]*`,
max 12 chars) if you write a `.har`.

## The family axis (opt-in, with caveats)

A household map claiming `fam` (see
`household_quintile_x_fam6.csv`) composes the family-formation layer onto the
cube at call time by biproportional fitting (RAS), reproducing the published
composition. `beta` follows the v0.8 construction; `gamma` follows the v1.0
transport, so the 642,600 composed rows are admissible too. Know what you are
buying:

- the layer is a **calibrated composition** from a 30-cell
  (family x quintile) donor; `w_fq` is national, with no family x state,
  family x age or family x region interaction. Cite the donor tier for
  inference, never the composed cube;
- composed groups can still carry negative gammas, but none prices a composite
  at x_G <= 0 any more: through v0.9 e.g. Q4 x F6 x H16 did, and
  `flagged = "keep"` was needed to get a result at all;
- `per = "capita"` / `"adult_equiv"` are refused with `fam`: no per-family
  persons measure exists, and the package does not invent one.

## `flagged` and `per`

- `flagged = "error"` (default): any output cell with x_G <= 0 stops the
  call, naming the cells. `"keep"`: algebraic passthrough with
  `flag_zero = 1`, exactly how the shipped elasticity matrix treats its own
  flagged rows. `"renormalize"`: floors x at 0, warns, and reports the
  adding-up break in the audit.
- `per`: `"cu"` (default), `"capita"`, `"adult_equiv"` divide the levels
  (gamma, M_bar, x, Gamma) by group means of persons or the OECD-modified
  scale. Shares and elasticities are bit-identical across `per`.

## Provenance

The parameters ship as release cut `frisch_friedman_v1.5.0-tier2` of the
LES-USA project (2017-2019 CEX window). The build script md5-gates every
input against the cut's `MANIFEST.csv`; the source checksums ride in
`les_data()$meta$source_md5`. Two demographic inputs come from the pipeline
rather than from the cut, so the manifest cannot cover them; they are pinned by
md5 in the build script and recorded in `les_data()$meta$pipeline_md5`. Rebuild
from the shipped files: `data-raw/build_les_usa_rds.R`. Test suite:
`Rscript tests/run_all.R`.

Estimation methodology, identification and validation are documented in
the companion paper (see `CITATION.cff`); the paper, not this README, is
the reference for how the numbers were produced.

## Citation

See `CITATION.cff` (GitHub renders it under "Cite this repository").
An archived copy of each release receives a DOI via Zenodo; until the
first DOI is minted, cite the release tag and the companion paper.

## License

Code is released under the MIT license (`LICENSE.md`). The parameter
files under `inst/` and `data/` are released under CC BY 4.0: use them
freely, with attribution to the LES-USA project.
