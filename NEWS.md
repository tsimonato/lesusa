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
