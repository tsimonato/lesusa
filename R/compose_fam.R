# compose_fam.R -- internal: base-R port of the v1.0 family composition
# (release cut's compose_cube_v10.R, which is compose_cube_v08.R for beta and
# admissible_split.R for gamma; specs 074 and 077). Called only when the
# household correspondence claims `fam`. Constants, iteration order and the
# gamma path replicate the reference implementation exactly; composition is
# RAS/biproportional fitting, NEVER multiply-the-tilt-and-renormalize
# (CLAUDE.md rule 7 -- the two differ by up to 0.165 in absolute beta).
#
# beta is unchanged from v0.8: one RAS against the (w_fq) family margin.
# gamma is NOT allocated by a dev16 tilt any more. v1.0 transports the
# subsistence SHARE by a logit tilt levelled per parent cell in dollars, splits
# the cell budget across goods by a second RAS, and DERIVES gamma = x - beta*SUP.
# x > 0 and eps_own < 0 then hold by construction rather than by a floor.
#
# Returns list(par, cells):
#   par   642,600 rows: cell_id, fam6, good, beta, gamma
#   cells  15,300 rows: cell_id, fam6, N_cu, M_bar (M_bar = mbar_cell *
#          ratio_mf at full precision -- the composer's own value, not the
#          rounded M_bar_f echo in the mass file)

compose_fam <- function(les, sup_min = 0.01, tol = 1e-12, max_it = 100L) {
  par   <- les$par
  cells <- les$cells
  goods <- les$goods
  tilts <- les$fam_tilts
  marg  <- les$fam_margins
  fmass <- les$fam_cells
  flog  <- les$fam_logit                        # q, fam6, tilt      (donor)
  fseed <- les$fam_seed                         # q, fam6, parent, seed_tilt
  stopifnot(is.data.frame(flog), is.data.frame(fseed))

  fam_lv <- sort(unique(marg$fam6))
  nf <- length(fam_lv)
  stopifnot(nf == 6L)

  ci    <- match(par$cell_id, cells$cell_id)
  q_row <- (cells$decile[ci] + 1L) %/% 2L                     # quintile of row
  p_row <- goods$parent[match(par$good, goods$good)]          # parent of row

  # (q, parent) x fam lookup matrices: T seeds the beta RAS, seed_tilt the
  # gamma RAS. dev16 is v0.8 machinery and is not read at v1.0.
  qp_row <- paste(q_row, p_row)
  qp_lev <- unique(paste(tilts$q, tilts$parent))
  Tm  <- matrix(NA_real_, length(qp_lev), nf,
                dimnames = list(qp_lev, fam_lv))
  Sm  <- Tm
  Tm[cbind(match(paste(tilts$q, tilts$parent), qp_lev),
           match(tilts$fam6, fam_lv))] <- tilts$T
  Sm[cbind(match(paste(fseed$q, fseed$parent), qp_lev),
           match(fseed$fam6, fam_lv))] <- fseed$seed_tilt
  stopifnot(!anyNA(Tm), all(Tm > 0), !anyNA(Sm), all(Sm > 0))
  ri <- match(qp_row, qp_lev)

  # (q x fam) child logit tilt, mean-zero under the donor's own mass
  Lm <- matrix(NA_real_, 5L, nf, dimnames = list(NULL, fam_lv))
  Lm[cbind(flog$q, match(flog$fam6, fam_lv))] <- flog$tilt
  stopifnot(!anyNA(Lm))

  # (fam x q) margins
  Wm <- matrix(NA_real_, nf, 5L, dimnames = list(fam_lv, NULL))
  Rm <- Wm
  Wm[cbind(match(marg$fam6, fam_lv), marg$q)] <- marg$w_fq
  Rm[cbind(match(marg$fam6, fam_lv), marg$q)] <- marg$ratio_mf
  stopifnot(!anyNA(Wm), !anyNA(Rm))

  ## --------------------------------------------------- beta: RAS ----------
  beta <- par$beta
  B <- beta * Tm[ri, , drop = FALSE]                          # seed
  cid <- ci                                                    # 1..2550 group
  it <- 0L; dev <- Inf
  repeat {
    it <- it + 1L
    rs <- rowsum(B, cid)                                       # 2550 x 6
    B  <- B / rs[cid, , drop = FALSE]                          # row pass
    s  <- rowSums(B * t(Wm)[q_row, , drop = FALSE])            # col margin
    dev <- max(abs(s - beta))
    if (dev < tol || it >= max_it) break
    B <- B * ifelse(s > 0, beta / s, 1)                        # col pass
  }
  if (!(dev < tol))
    warning("family RAS stopped at max_it with column deviation ",
            format(dev), call. = FALSE)
  if (any(!is.finite(B)) || any(B <= 0))
    stop("family composition produced inadmissible beta (non-finite or ",
         "<= 0); refusing to continue.", call. = FALSE)

  ## ------------------------------------------ gamma: the v1.0 transport ---
  gamma  <- par$gamma
  qc     <- (cells$decile + 1L) %/% 2L
  mbar_f <- outer(cells$M_bar, rep(1, nf)) *
            t(Rm)[qc, , drop = FALSE]                      # 2550 x 6 (m_c)
  n_c    <- matrix(NA_real_, nrow(cells), nf, dimnames = list(NULL, fam_lv))
  n_c[cbind(match(fmass$cell_id, cells$cell_id),
            match(fmass$fam6, fam_lv))] <- fmass$N_cu_f
  stopifnot(!anyNA(n_c), all(n_c > 0))

  Gam   <- rowsum(gamma, cid)[, 1L]                        # Gamma_c per cell
  Mbar  <- cells$M_bar
  S_par <- Gam / Mbar
  stopifnot(all(S_par > 0), all(S_par < 1))
  x_par <- gamma + beta * (Mbar[cid] - Gam[cid])           # parent x by good
  stopifnot(all(x_par > 0))

  ## level: one root per parent cell. The margin is in DOLLARS -- the published
  ## child budgets do not average back to the parent budget, so a share
  ## condition would leave the column margins inconsistent.
  l0 <- stats::qlogis(S_par)
  kv <- vapply(seq_len(nrow(cells)), function(j) {
    tl <- Lm[qc[j], ]; nn <- n_c[j, ]; mm <- mbar_f[j, ]
    tg <- sum(nn) * S_par[j] * Mbar[j]
    f  <- function(kk) sum(nn * mm * stats::plogis(l0[j] + tl + kk)) - tg
    if (f(-12) > 0 || f(12) < 0)
      stop("compose_fam: child logit level not reachable on [-12, 12].",
           call. = FALSE)
    stats::uniroot(f, c(-12, 12), tol = 1e-12)$root
  }, numeric(1))

  S_c   <- stats::plogis(l0 + Lm[qc, , drop = FALSE] + kv)     # 2550 x 6
  SUP_c <- mbar_f * (1 - S_c)
  rw    <- n_c / rowSums(n_c)
  r_c   <- rw * mbar_f                                         # row margins

  ## column target: the parent's subsistence by good plus the children's
  ## supernumerary spending on it -- NOT the parent's expenditure, which would
  ## make the column sum M_par instead of Gamma_par and break the level margin.
  Xt   <- gamma + rowSums(B * rw[cid, , drop = FALSE] * SUP_c[cid, , drop = FALSE])
  ## Two floors, the larger binds: 1% of the parent's own expenditure on the
  ## good, and the eta band sum_f r_f*beta_fg / ETA_MAX (the children's average
  ## share of the good cannot fall below beta/ETA_MAX). Raised targets are paid
  ## for out of the columns above their floor, in proportion, so the column
  ## total -- and with it the level margin the k-step just pinned -- survives.
  ## Mirrors admissible_split.R (ETA_MAX, floor_columns).
  LB   <- r_c[cid, , drop = FALSE] * B / ETA_MAX              # per-child bound
  flr  <- pmax(0.01 * x_par, rowSums(LB))
  Xt   <- unlist(lapply(split(seq_along(Xt), cid), function(ix)
    floor_columns(Xt[ix], flr[ix])), use.names = FALSE)[order(order(cid))]

  ## per-good split: one bounded RAS per parent cell (6 families x 42 goods)
  u0 <- r_c[cid, , drop = FALSE] * (x_par / Mbar[cid]) * Sm[ri, , drop = FALSE]
  stopifnot(all(u0 > 0))
  rows <- split(seq_len(nrow(par)), cid)
  U    <- matrix(NA_real_, nrow(par), nf)
  its  <- integer(length(rows))
  for (j in seq_along(rows)) {
    rj  <- rows[[j]]
    fit <- ras_split(t(u0[rj, , drop = FALSE]), r_c[j, ], Xt[rj],
                     lower = t(LB[rj, , drop = FALSE]))
    its[j]  <- fit$it
    U[rj, ] <- t(fit$u)
  }
  if (max(its) > 60L)
    stop("compose_fam: family RAS needed ", max(its), " passes (> 60).",
         call. = FALSE)

  w_c <- U / r_c[cid, , drop = FALSE]
  x_c <- mbar_f[cid, , drop = FALSE] * w_c
  if (any(!is.finite(x_c)) || any(x_c <= 0))
    stop("compose_fam: family composition produced x <= 0 in ",
         sum(!(x_c > 0)), " rows; refusing to continue.", call. = FALSE)
  if (any(B / w_c > ETA_MAX * (1 + 1e-9)))
    stop("compose_fam: eta > ETA_MAX in ", sum(B / w_c > ETA_MAX * (1 + 1e-9)),
         " rows; the bounded RAS did not hold.", call. = FALSE)
  G <- x_c - B * SUP_c[cid, , drop = FALSE]                    # gamma, DERIVED

  ## -------------------------------------------------------- assemble ------
  par_f <- data.frame(
    cell_id = rep(par$cell_id, nf),
    fam6    = rep(fam_lv, each = nrow(par)),
    good    = rep(par$good, nf),
    beta    = as.vector(B),
    gamma   = as.vector(G),
    stringsAsFactors = FALSE)

  mb <- data.frame(cell_id = rep(cells$cell_id, nf),
                   fam6    = rep(fam_lv, each = nrow(cells)),
                   M_bar   = as.vector(mbar_f),
                   stringsAsFactors = FALSE)
  cf <- merge(fmass[c("cell_id", "fam6", "N_cu_f")], mb,
              by = c("cell_id", "fam6"), sort = FALSE)
  names(cf)[names(cf) == "N_cu_f"] <- "N_cu"
  stopifnot(nrow(cf) == nrow(cells) * nf, !anyNA(cf))

  list(par = par_f, cells = cf)
}

# ras_split() -- biproportional fit of a strictly positive matrix to given
# margins. Port of the reference `admissible_split.R`. The margins are
# consistent by construction at every call site (that is what the level step
# buys), so a failure here is a design error upstream, not a tolerance problem:
# it stops rather than returning. tol is set against the precision of the FILE,
# not of the computation (CLAUDE.md rule 10) -- gamma ships at 4 dp, so the
# inputs carry an inconsistency of ~2.5e-09 that no fit can beat. Floor the
# tolerance at ten times the observed gap instead of stalling for 200 passes.
#
# `lower` (optional, same shape as u0) makes it a BOUNDED fit: run the plain
# fit, pin every entry that fell below its bound at the bound, refit the free
# entries to the reduced margins, repeat until nothing new is pinned. The
# family composition uses it to hold eta = beta/w <= ETA_MAX on every row.
ras_split <- function(u0, r_tot, x_tot, tol = 1e-10, max_it = 200L,
                      lower = NULL) {
  stopifnot(is.matrix(u0), all(u0 > 0), all(r_tot > 0), all(x_tot > 0),
            nrow(u0) == length(r_tot), ncol(u0) == length(x_tot))
  gap <- abs(sum(r_tot) - sum(x_tot)) / sum(r_tot)
  if (gap > 1e-6)
    stop("ras_split: margins inconsistent by ", signif(gap, 3),
         " -- the level step did not pin the parent total", call. = FALSE)
  if (tol < 10 * gap) tol <- 10 * gap
  if (!is.null(lower)) {
    stopifnot(is.matrix(lower), identical(dim(lower), dim(u0)),
              all(lower >= 0), all(rowSums(lower) < r_tot),
              all(colSums(lower) <= x_tot * (1 + 1e-9)))
  }
  fixed <- matrix(FALSE, nrow(u0), ncol(u0))
  u <- u0
  it_total <- 0L
  for (round in seq_len(50L)) {
    rf <- r_tot - rowSums(u * fixed)
    xf <- x_tot - colSums(u * fixed)
    free_col <- colSums(!fixed) > 0L
    uf <- u; uf[fixed] <- 0
    dev <- Inf
    for (it in seq_len(max_it)) {
      uf <- uf * (rf / rowSums(uf))                        # row step
      cs <- colSums(uf)
      dev <- max(abs(cs - xf)[free_col] / x_tot[free_col])
      if (dev < tol) break
      fac <- ifelse(free_col & cs > 0, xf / cs, 1)
      uf <- sweep(uf, 2L, fac, `*`)                        # column step
    }
    it_total <- it_total + it
    if (!(dev < tol)) {
      if (is.null(lower))
        stop("ras_split: no convergence in ", max_it, " passes, dev = ",
             signif(dev, 3), call. = FALSE)
      return(ras_split_residual(u0, r_tot, x_tot, lower, tol, max_it,
                                it_total, why = paste0("no convergence in ",
                                max_it, " passes, dev = ", signif(dev, 3))))
    }
    u[!fixed] <- uf[!fixed]
    if (is.null(lower))
      return(list(u = u, it = it_total, dev = dev, n_bounded = 0L))
    viol <- !fixed & (u < lower * (1 - 1e-12))
    if (!any(viol))
      return(list(u = u, it = it_total, dev = dev, n_bounded = sum(fixed)))
    u[viol] <- lower[viol]
    fixed <- fixed | viol
  }
  ras_split_residual(u0, r_tot, x_tot, lower, tol, max_it, it_total,
                     why = "bounded fit did not settle in 50 rounds")
}

# ras_split_residual() -- fallback when the active-set loop cannot settle.
# Pinning entries at their bound and never releasing them can make the
# remaining transport infeasible even when the original is not. u = lower + v
# with v fitted by plain RAS to the residual margins is exact and feasible
# whenever the residuals are non-negative (guaranteed by the bound check).
# Fallback only: every split that settled before stays byte-identical.
# Mirrors R/recover/admissible_split.R.
ras_split_residual <- function(u0, r_tot, x_tot, lower, tol, max_it, it_prev,
                               why) {
  rr <- r_tot - rowSums(lower)
  xr <- x_tot - colSums(lower)
  xr[xr < 0 & xr > -1e-9 * max(x_tot)] <- 0
  if (any(rr <= 0) || any(xr < 0))
    stop("ras_split: active-set fit failed (", why, ") and the residual ",
         "transport is infeasible: min row residual ", signif(min(rr), 3),
         ", min column residual ", signif(min(xr), 3), call. = FALSE)
  keep <- xr > 0
  v <- pmax(u0 - lower, 1e-3 * mean(u0))[, keep, drop = FALSE]
  dev <- Inf
  for (it in seq_len(25L * max_it)) {
    v  <- v * (rr / rowSums(v))
    cs <- colSums(v)
    dev <- max(abs(cs - xr[keep]) / x_tot[keep])
    if (dev < tol) break
    v <- sweep(v, 2L, xr[keep] / cs, `*`)
  }
  if (!(dev < tol))
    stop("ras_split: residual fit did not converge either (", why,
         "; residual dev = ", signif(dev, 3), ")", call. = FALSE)
  u <- lower
  u[, keep] <- lower[, keep, drop = FALSE] + v
  list(u = u, it = it_prev + it, dev = dev, n_bounded = sum(!keep) * nrow(u0),
       fallback = why)
}

# ETA_MAX -- the construction band on eta = beta/w, mirrored from
# admissible_split.R. Imposed on x, never on beta. 10 for the v1.0 cube;
# 4.0 for v1.1; 4.89 from v1.2 (PI decision 2026-09-14). The band is NOT the
# export ceiling and does not deliver it: exact LES aggregation exceeds the
# largest row it merges by up to 7.2% over the 178 listed classifications, so
# 16 of them come out above 5 and les_aggregate() refuses them by default
# rather than returning them quietly. 4.89 was chosen because it clips nothing
# at the repaired donor (max 4.70) and keeps the CGE grid (4.96) inside the
# ceiling; 4.66 would put all 178 under 5 but would clip the donor.
# v1.1 needed a far lower band because the donor
# itself carried eta 10.6; v1.2 repairs the donor at the source
# (admissible_split.R, repair_donor), so the band no longer clips a precisely
# estimated vehicle plateau -- it costs 54 extra pinned rows, 0.98% of the cube.
ETA_MAX <- 4.89
# ETA_EXPORT -- the band les_aggregate() checks on every row it returns.
# PI ceiling of 2026-09-13: no export a TERM user can request may carry an
# expenditure elasticity above 5. It was 12 (ETA_MAX plus mixing slack) until
# that date, which let the decile-2/4 recreation and vehicle rows of the v1.0
# cube (eta up to 10) ship without a warning. tests/test_export_admissibility.R
# asserts this value, so the test and the package cannot drift apart again.
ETA_EXPORT <- 5

# floor_columns() -- raise column targets below `flr` to `flr`, paying for it
# proportionately out of the columns above their floor, until every column is
# at or above its floor and the total is preserved.
floor_columns <- function(Xt, flr) {
  stopifnot(length(Xt) == length(flr), sum(flr) < sum(Xt))
  tot <- sum(Xt)
  for (i in seq_len(50L)) {
    bad <- Xt < flr
    if (!any(bad)) break
    need <- sum(flr[bad] - Xt[bad])
    pos  <- sum(Xt[!bad])
    Xt[bad]  <- flr[bad]
    Xt[!bad] <- Xt[!bad] * (1 - need / pos)
  }
  stopifnot(all(Xt >= flr * (1 - 1e-12)), abs(sum(Xt) - tot) < 1e-9 * tot)
  Xt
}
