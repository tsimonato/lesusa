# compose_fam.R -- internal: base-R port of the v0.8 family composition
# (release cut's compose_cube_v08.R, spec 074). Called only when the
# household correspondence claims `fam`. Constants, iteration order and the
# gamma path replicate the reference implementation exactly; composition is
# RAS/biproportional fitting, NEVER multiply-the-tilt-and-renormalize
# (CLAUDE.md rule 7 -- the two differ by up to 0.165 in absolute beta).
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

  fam_lv <- sort(unique(marg$fam6))
  nf <- length(fam_lv)
  stopifnot(nf == 6L)

  ci    <- match(par$cell_id, cells$cell_id)
  q_row <- (cells$decile[ci] + 1L) %/% 2L                     # quintile of row
  p_row <- goods$parent[match(par$good, goods$good)]          # parent of row

  # (q, parent) x fam lookup matrices for T and dev16
  qp_row <- paste(q_row, p_row)
  qp_lev <- unique(paste(tilts$q, tilts$parent))
  Tm  <- matrix(NA_real_, length(qp_lev), nf,
                dimnames = list(qp_lev, fam_lv))
  Dm  <- Tm
  idx <- cbind(match(paste(tilts$q, tilts$parent), qp_lev),
               match(tilts$fam6, fam_lv))
  Tm[idx] <- tilts$T
  Dm[idx] <- tilts$dev16
  stopifnot(!anyNA(Tm), !anyNA(Dm), all(Tm > 0))
  ri <- match(qp_row, qp_lev)

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

  ## ------------------------------------------- gamma: dev16 allocation ----
  gamma <- par$gamma
  cp    <- paste(par$cell_id, p_row)                           # (cell, parent)
  cp_f  <- factor(cp, levels = unique(cp))
  gsum  <- rowsum(gamma, cp_f)[as.integer(cp_f)]
  bsum  <- rowsum(beta,  cp_f)[as.integer(cp_f)]
  aw    <- ifelse(abs(gsum) > 1e-6, gamma / gsum, beta / bsum)
  DG    <- aw * Dm[ri, , drop = FALSE]                         # dev_g (rows x f)

  mbar_f <- outer(cells$M_bar, rep(1, nf)) * t(Rm)[ (cells$decile + 1L) %/% 2L,
                                                    , drop = FALSE]  # 2550 x 6
  sg   <- rowsum(gamma, cid)[, 1L]                             # Gamma_c
  sdev <- rowsum(DG, cid)                                      # 2550 x 6
  cap  <- (1 - sup_min) * mbar_f
  lam  <- ifelse(sdev <= 0, 1,
                 ifelse(sg + sdev <= cap, 1,
                        pmax(0, (cap - sg) / sdev)))
  G <- gamma + lam[cid, , drop = FALSE] * DG
  sg2   <- rowsum(G, cid)
  theta <- ifelse(sg2 > cap & sg2 > 0, pmin(1, cap / sg2), 1)
  G <- G * theta[cid, , drop = FALSE]

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
