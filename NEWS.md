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
