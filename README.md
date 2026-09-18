# lesusa

**Stone-Geary (LES) demand parameters for the United States, with aggregation that is exact at the base point.**

[![Version](https://img.shields.io/badge/version-0.4.0-blue)](NEWS.md)
[![R](https://img.shields.io/badge/R-%E2%89%A5%204.1-276DC3?logo=r)](https://www.r-project.org/)
[![Release cut](https://img.shields.io/badge/cut-frisch__friedman__v1.7.0--tier2-6f42c1)](#provenance)
[![Code](https://img.shields.io/badge/code-MIT-green)](LICENSE)
[![Data](https://img.shields.io/badge/data-CC%20BY%204.0-green)](LICENSE.md)

A calibrated Linear Expenditure System for 2,550 US household cells and 42 goods, estimated on the
2017-2019 Consumer Expenditure Survey, with one function that collapses the grid to whatever
classification your model uses. The aggregation is not an average: it reproduces aggregate demand
with no error and preserves adding-up, Engel aggregation, homogeneity and the Cournot condition by
construction.

Built for CGE and microsimulation work. Writes GEMPACK `.har` directly.

---

## Install

```r
# install.packages("remotes")
remotes::install_github("tsimonato/lesusa")
```

No compiled code, no hard dependency beyond base R. `HARr` is needed only to write `.har`.

## Quickstart

```r
library(lesusa)

cdir <- system.file("correspondence", package = "lesusa")
g16  <- read.csv(file.path(cdir, "goods_42_to_16.csv"),             comment.char = "#")
hq   <- read.csv(file.path(cdir, "household_decile_to_quintile.csv"), comment.char = "#")
r4   <- read.csv(file.path(cdir, "regions_51_to_4.csv"),            comment.char = "#")

res <- les_aggregate(goods = g16, regions = r4, household = hq)
#> les_aggregate: 20 output cells x 16 goods | max|sum beta - 1| = 6.7e-16 | level repro = 0.0e+00

head(res$par)     # beta, gamma, x, w, eta, eps_own per output cell and commodity
head(res$cells)   # N_cu, M_bar, Gamma, SUP, S, phi, demographics
res$audit         # the checks the call ran on itself
```

A correspondence is a data frame, a CSV path or a named vector. Omit a dimension and it collapses.
Pass `file = "mymodel"` to write `mymodel.har`, `mymodel.csv` and `mymodel_cells.csv`.

## The grid

| Dimension | Resolution | Native key |
| --- | --- | --- |
| Geography | 50 states and DC | `state` |
| Income | 10 deciles of disposable income | `decile` |
| Age | 5 bands of the reference person | `age` |
| Goods | 42, nested under 16 groups | `good` |
| Family (opt-in) | 6 formation types | `fam` |

2,550 cells times 42 goods is 107,100 parameter rows. Asking for `fam` composes a sixth axis at call
time and yields 642,600, never stored on disk.

The window is 2017-2019, pooled. The cells carry survey weights summing to 138.7 million consumer
units.

## What is exact, and what is not

The aggregation is exact **at the base point**, which is a precise and limited claim. Subsistence
and mean outlay aggregate by consumer-unit mass, marginal budget shares by supernumerary mass, and
every derived quantity is recomputed from the closed forms rather than averaged. The aggregated
system therefore reproduces the disaggregated demand at observed prices and budgets, not away from
them.

Every call audits itself and refuses to return an inconsistent result. Measured on the shipped
release:

| Identity | Residual |
| --- | --- |
| Adding-up, `max abs(sum_g beta - 1)` | 6.7e-16 |
| Engel aggregation, `sum_g w_g eta_g = 1` | 6.7e-16 |
| Level reproduction | 0.0e+00 |
| Homogeneity (`cross_price = TRUE`) | 8.9e-16 |
| Cournot (`cross_price = TRUE`) | 1.4e-16 |

Measured on the 16-good by 4-region by quintile call in the quickstart above. The audit tolerance
is 1e-10, so the realised residuals sit four orders of magnitude inside it.

Three things the cube is not, stated plainly because they are easy to assume:

**It is a calibrated composition, not a 51-state estimation.** Formal inference lives in the donor
systems: a national income-decile LES and a 41-state layer, both estimated by constrained NLSUR.
The state, age and family axes are transported onto that base by a logit level and biproportional
fitting. Column `tier` grades every cell by how much survey it rests on: 22 states are `T1`, 19 are
`T2`, and the 10 with no CEX interviews at all are `T3`, placed by iterative proportional fitting.
`share_ipf` carries into the output as a mass-weighted share, so a merged cell tells you how much
of itself came from that route. Treat high-`share_ipf` groups as model-based, not survey-based.

**Subsistence is non-negative, on every row.** Since cube v1.3 (0.4.0) `gamma >= 0` holds on all
642,600 native rows and on every output cell `les_aggregate()` can produce; the function re-checks it
and refuses to return a table that breaks it. Through 0.3.0 it did not hold — 10.1% of native rows
carried `gamma < 0` — and the note here called that legitimate. For Stone-Geary as a utility function
it was, since only `x > gamma` is required; but a negative subsistence *quantity* has no reading in
the CGE demand systems that consume this package, and one of them rejected the 0.3.0 export for
exactly that reason. The equivalent statement inside the LES is `eta_c <= M_bar / SUP`: no good may
respond to income more strongly than the cell's own Frisch parameter. That ceiling binds hardest
where the supernumerary share is largest, so income elasticities in the top deciles are capped near
1.4-1.7; 14.2% of rows sit at the floor with `eps_own = -1`. See `NEWS.md` for the rule and its cost.

**No standard errors travel with the grid.** Only the state-level subsistence share `S_M` carries
one, in the `states` table. Aggregated parameters are calibrated quantities, so do not attach
inferential language to them: cite the donor tier for inference, never the composed cube.

## The elasticity band, and what the package guarantees

Positive expenditure bounds the income elasticity `eta = beta / w` below but not above. Where a
cell's expenditure on a good is small, the ratio can run to three or four figures while every
admissibility test still passes. The transport therefore holds a band, and the band binds on
expenditure, never on `beta`, so adding-up and the estimated marginal shares are untouched.

- **Native rows: `eta <= 4.89` by construction.**
- **Exports: exact aggregates.** Aggregation weights `beta` by supernumerary mass and `x` by
  consumer-unit mass, so a merged cell can exceed the largest row it merges. Across the 178
  classifications the release sweep drives, that excess reaches 7.2%.
- **`les_aggregate()` refuses, by default, to return or write any row above 5**, naming the
  offending rows. Sixteen of those 178 classifications need an explicit `eta_over = "warn"` or
  `"keep"`, and all sixteen merge across income deciles inside a single state. The 16-commodity by
  51-state by 10-decile grid a CGE pipeline typically reads is not among them.

The guarantee is that nothing above the ceiling is ever returned silently, not that nothing above
it exists. Asking for the exact aggregate of an extreme partition is legitimate; receiving it
without knowing is not.

## Correspondences

Eight worked mappings ship in `inst/correspondence/`, each a CSV that lists native keys first and
the output label last, with its provenance in the header: 42 goods to 16 or to 2, the 51 state rows
to 9 census divisions or 4 regions, deciles to quintiles, ages to 3 bands, and two household
crosses, which cross decile with age or with age and family. Write your own the same way. Every native
element must map exactly once, and a violation is an error that names the offenders rather than a
silent drop.

## The family axis

`fam` is opt-in and composed at call time from a factorized layer by biproportional fitting, not by
multiplying a tilt onto `beta` and renormalizing. The two differ materially. Read the caveats in
`?les_aggregate` before using it: `per` is restricted to consumer units on that axis, because no
person count exists by family type and inventing one would be false precision.

## Provenance

The parameters are release cut `frisch_friedman_v1.7.0-tier2` (cube v1.3). The build script
md5-gates every input against the cut manifest and refuses to run on a drifted file. Checksums
travel with the data:

```r
les <- lesusa:::les_data()
les$meta$cut            # the release cut this rds was built from
les$meta$source_md5     # every cut file, with its md5
les$meta$pipeline_md5   # the two demographic inputs that sit outside the cut
les$meta$honesty        # what the numbers do not support
```

`les_aggregate()` is the whole public API by design. The shipped tables are reachable through
`lesusa:::les_data()` for inspection, and their schema is documented in the cut.

## Citation

```bibtex
Simonato, T. (2026). LES-USA: Stone-Geary parameter database for the United States,
2017-2019 (frisch_friedman_v1.7.0-tier2) [Data set and R package, version 0.4.0].
https://github.com/tsimonato/lesusa
```

`CITATION.cff` carries the machine-readable form.

## License

Code MIT. Parameter files CC BY 4.0. The underlying microdata is the public-use Consumer
Expenditure Survey from the Bureau of Labor Statistics and carries its own terms.
