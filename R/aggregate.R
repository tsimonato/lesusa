# aggregate.R -- the one exported function (spec 073 D3).
# Exact aggregation of the LES cube to user classifications:
#   beta  aggregates by supernumerary mass  w_sup = N_c*(M_c - Gamma_c)
#   gamma, M_bar aggregate by CU mass       w_cu  = N_c
#   (D-072-02); everything derived (x, w, eta, eps, S, phi) is RE-DERIVED
#   from the aggregated primitives via the closed forms of
#   R/recover/elasticity_matrix_v07.R:14-48 -- never averaged.
# Every call self-audits (AC1/AC2) and refuses inconsistent output.

#' Aggregate the LES-USA parameter database to a user classification
#'
#' @param goods,regions,household correspondences: CSV path, data.frame, or
#'   named vector. Native keys: `good` (goods); `state` (regions); `decile`,
#'   `age`, optionally `state`, optionally `fam` (household). A missing map
#'   collapses its dimension to one element. Claiming `fam` composes the v0.8
#'   family layer at call time (RAS; see README caveats).
#' @param file output basename: writes `<file>.har`, `<file>.csv`,
#'   `<file>_cells.csv`. NULL (default) writes nothing.
#' @param per report levels per "cu" (default), "capita" or "adult_equiv".
#'   Divides gamma, M_bar, x, Gamma only; shares and elasticities untouched.
#' @param flagged what to do when an aggregated x_G <= 0: "error" (default),
#'   "keep" (algebraic passthrough with flag_zero = 1, exactly what the
#'   shipped elasticity matrix does for its own 1,781 flagged rows), or
#'   "renormalize" (floor at 0, warn, report the adding-up break).
#' @param cross_price also return/check the full cross-price block.
#' @return (invisibly) list(par, cells, audit) and, if requested, `cross`.
#' @export
les_aggregate <- function(goods = NULL, regions = NULL, household = NULL,
                          file = NULL, per = c("cu", "capita", "adult_equiv"),
                          flagged = c("error", "keep", "renormalize"),
                          cross_price = FALSE) {
  per     <- match.arg(per)
  flagged <- match.arg(flagged)
  les <- les_data()

  gm <- if (!is.null(goods))     read_map(goods, "goods")
  rg <- if (!is.null(regions))   read_map(regions, "regions")
  hh <- if (!is.null(household)) read_map(household, "household")
  check_claims(list(gm, rg, hh))
  fam_on <- !is.null(hh) && "fam" %in% hh$keys
  if (fam_on && per != "cu")
    stop('per = "', per, '" is not available with a household map that ',
         'claims `fam`: no persons_bar/eqsc_bar exists by family type, and ',
         "inventing one from category labels would be fake precision.",
         call. = FALSE)

  ## ------------------------------------------------- native tables --------
  meta_cells <- les$cells[c("cell_id", "state", "decile", "age", "tier",
                            "src", "share_ipf_state", "persons_bar",
                            "eqsc_bar", "demog_src")]
  if (fam_on) {
    comp  <- compose_fam(les)
    par   <- comp$par
    cells <- merge(comp$cells, meta_cells, by = "cell_id", sort = FALSE)
  } else {
    par   <- les$par
    cells <- merge(les$cells[c("cell_id", "N_cu", "M_bar")], meta_cells,
                   by = "cell_id", sort = FALSE)
    cells$fam6 <- "all"
    par$fam6   <- "all"
  }

  ## --------------------------------------------------- output labels ------
  par$COM <- if (!is.null(gm))
    apply_map(gm, data.frame(good = par$good, stringsAsFactors = FALSE))
  else "ALL"
  cells$REG <- if (!is.null(rg))
    apply_map(rg, data.frame(state = cells$state, stringsAsFactors = FALSE))
  else "USA"
  cells$HH <- if (!is.null(hh)) {
    hdf <- cells[intersect(c("decile", "age", "state", "fam6"), names(cells))]
    names(hdf)[names(hdf) == "fam6"] <- "fam"
    apply_map(hh, hdf[hh$keys])
  } else "ALL"

  ## ------------------------------------------ cell-level primitives -------
  key_c <- paste(cells$cell_id, cells$fam6)
  Gam_c <- rowsum(par$gamma, paste(par$cell_id, par$fam6))[key_c, 1L]
  cells$Gamma <- Gam_c
  cells$SUP   <- cells$M_bar - cells$Gamma
  if (any(cells$SUP <= 0))
    stop("internal: SUP_c <= 0 at native cell level", call. = FALSE)

  # native flagged rows (x_cg <= 0) for the honesty count
  sup_row <- cells$SUP[match(paste(par$cell_id, par$fam6), key_c)]
  x_row   <- par$gamma + par$beta * sup_row
  ncu_row <- cells$N_cu[match(paste(par$cell_id, par$fam6), key_c)]

  ## ------------------------------------- goods pass within (cell, COM) ----
  gkey  <- paste(par$cell_id, par$fam6, par$COM, sep = "\r")
  glev  <- unique(gkey)
  bG    <- rowsum(par$beta,  gkey)[glev, 1L]
  gG    <- rowsum(par$gamma, gkey)[glev, 1L]
  negG  <- rowsum(as.numeric(x_row <= 0), gkey)[glev, 1L]
  gmap  <- do.call(rbind, strsplit(glev, "\r", fixed = TRUE))
  gcell <- data.frame(ck = paste(gmap[, 1L], gmap[, 2L]), COM = gmap[, 3L],
                      beta = bG, gamma = gG, n_neg = negG,
                      stringsAsFactors = FALSE)

  ## ------------------------------------------- cell pass within groups ----
  ci <- match(gcell$ck, key_c)
  grp_cell <- paste(cells$REG, cells$HH, sep = "\r")     # per native cell
  grp_row  <- grp_cell[ci]                               # per (cell, COM) row
  w_cu_raw  <- cells$N_cu
  w_sup_raw <- cells$N_cu * cells$SUP
  den_cu  <- rowsum(w_cu_raw,  grp_cell)
  den_sup <- rowsum(w_sup_raw, grp_cell)
  glev2 <- rownames(den_cu)
  wc <- w_cu_raw  / den_cu [match(grp_cell, glev2), 1L]
  ws <- w_sup_raw / den_sup[match(grp_cell, glev2), 1L]

  okey <- paste(grp_row, gcell$COM, sep = "\r")
  olev <- unique(okey)
  beta_o  <- rowsum(gcell$beta  * ws[ci], okey)[olev, 1L]
  gamma_o <- rowsum(gcell$gamma * wc[ci], okey)[olev, 1L]
  nneg_o  <- rowsum(gcell$n_neg,          okey)[olev, 1L]
  omap <- do.call(rbind, strsplit(olev, "\r", fixed = TRUE))
  out <- data.frame(REG = omap[, 1L], HH = omap[, 2L], COM = omap[, 3L],
                    beta = beta_o, gamma = gamma_o,
                    n_neg_absorbed = as.integer(nneg_o),
                    stringsAsFactors = FALSE)

  # group-level cells companion
  gl <- data.frame(
    REG = sub("\r.*", "", glev2), HH = sub(".*\r", "", glev2),
    N_cu  = den_cu[, 1L],
    M_bar = rowsum(w_cu_raw * cells$M_bar, grp_cell)[glev2, 1L] / den_cu[, 1L],
    persons_bar = rowsum(w_cu_raw * cells$persons_bar, grp_cell)[glev2, 1L] /
      den_cu[, 1L],
    eqsc_bar = rowsum(w_cu_raw * cells$eqsc_bar, grp_cell)[glev2, 1L] /
      den_cu[, 1L],
    share_ipf = rowsum(w_cu_raw * cells$share_ipf_state, grp_cell)[glev2, 1L] /
      den_cu[, 1L],
    demog_cex_share = rowsum(w_cu_raw * (cells$demog_src == "cex"),
                             grp_cell)[glev2, 1L] / den_cu[, 1L],
    n_cells = as.integer(rowsum(rep(1, nrow(cells)), grp_cell)[glev2, 1L]),
    stringsAsFactors = FALSE)

  ## ------------------------------------------------------- re-derive ------
  okey2 <- paste(out$REG, out$HH, sep = "\r")
  gI    <- match(okey2, glev2)
  gl$Gamma <- rowsum(out$gamma, okey2)[glev2, 1L]
  gl$SUP   <- gl$M_bar - gl$Gamma
  gl$S     <- gl$Gamma / gl$M_bar
  gl$phi   <- -1 / (1 - gl$S)
  out$x   <- out$gamma + out$beta * gl$SUP[gI]
  out$w   <- out$x / gl$M_bar[gI]

  ## ------------------------------------------------------ flagged ---------
  audit <- list()
  bad <- which(out$x <= 0)
  out$flag_zero <- as.integer(seq_len(nrow(out)) %in% bad)
  renorm <- FALSE
  if (length(bad)) {
    if (flagged == "error") {
      ex <- utils::head(paste0(out$REG[bad], "/", out$HH[bad], "/",
                               out$COM[bad]), 10L)
      stop("aggregated x_G <= 0 in ", length(bad), " output cell(s): ",
           paste(ex, collapse = "; "),
           if (length(bad) > 10L) " ..." else "",
           '. Coarsen the map, or use flagged = "keep" (algebraic ',
           'passthrough, as the shipped elasticity matrix does) or ',
           '"renormalize" (floor at 0, documenting the adding-up break).',
           call. = FALSE)
    }
    if (flagged == "renormalize") {
      renorm <- TRUE
      out$x[bad] <- 0
      out$w      <- out$x / gl$M_bar[gI]
      brk <- rowsum(out$w, gI)[, 1L]
      audit$addup_break <- max(abs(brk - 1))
      warning("flagged = 'renormalize': ", length(bad), " output cells ",
              "floored at x = 0; adding-up now breaks by up to ",
              format(audit$addup_break, digits = 3),
              " in sum(w); eta/eps are NA there.", call. = FALSE)
    } else {
      warning("flagged = 'keep': ", length(bad), " output cells have ",
              "x_G <= 0; w, eta, eps_own carry the algebraic values ",
              "(no direct economic interpretation; flag_zero = 1).",
              call. = FALSE)
    }
  }
  if (renorm) {
    out$eta     <- ifelse(out$flag_zero == 1L, NA_real_, out$beta / out$w)
    out$eps_own <- ifelse(out$flag_zero == 1L, NA_real_,
                          -1 + (1 - out$beta) * out$gamma / out$x)
  } else {
    out$eta     <- out$beta / out$w
    out$eps_own <- -1 + (1 - out$beta) * out$gamma / out$x
  }

  ## --------------------------------------------------------- audits -------
  sb <- rowsum(out$beta, gI)[, 1L]
  audit$max_dev_addup <- max(abs(sb - 1))
  if (renorm) {
    audit$max_dev_engel <- NA_real_
  } else {
    swe <- rowsum(out$w * out$eta, gI)[, 1L]
    audit$max_dev_engel <- max(abs(swe - 1))
  }
  audit$S_range <- range(gl$S)
  lvl_out <- sum(gl$N_cu * gl$M_bar)
  lvl_in  <- sum(cells$N_cu * cells$M_bar)
  audit$level_repro_rel <- abs(lvl_out - lvl_in) / lvl_in
  audit$n_neg_absorbed <- sum(out$n_neg_absorbed)
  tolA <- 1e-10; tolL <- 1e-12
  if (audit$max_dev_addup > tolA)
    stop("AUDIT FAIL: max|sum(beta)-1| = ", audit$max_dev_addup, call. = FALSE)
  if (!renorm && audit$max_dev_engel > tolA)
    stop("AUDIT FAIL: max|sum(w*eta)-1| = ", audit$max_dev_engel, call. = FALSE)
  if (any(gl$S <= 0 | gl$S >= 1))
    stop("AUDIT FAIL: S outside (0,1)", call. = FALSE)
  if (audit$level_repro_rel > 1e-9)
    stop("AUDIT FAIL: level reproduction off by ", audit$level_repro_rel,
         call. = FALSE)

  cross <- NULL
  if (cross_price) {
    sp <- split(seq_len(nrow(out)), gI)
    cross <- do.call(rbind, lapply(sp, function(ix) {
      o <- out[ix, ]
      e <- outer(o$beta / ifelse(o$x == 0, NA_real_, o$x), o$gamma,
                 function(b, g) -b * g)
      diag(e) <- o$eps_own
      data.frame(REG = o$REG[1L], HH = o$HH[1L],
                 COM_g = rep(o$COM, times = nrow(o)),
                 COM_j = rep(o$COM, each  = nrow(o)),
                 eps = as.vector(e), stringsAsFactors = FALSE)
    }))
    rownames(cross) <- NULL
    if (!renorm) {
      hom <- vapply(sp, function(ix) {
        o <- out[ix, ]
        e <- outer(o$beta / o$x, o$gamma, function(b, g) -b * g)
        diag(e) <- o$eps_own
        max(abs(rowSums(e) + o$eta))
      }, numeric(1))
      cou <- vapply(sp, function(ix) {
        o <- out[ix, ]
        e <- outer(o$beta / o$x, o$gamma, function(b, g) -b * g)
        diag(e) <- o$eps_own
        max(abs(colSums(o$w * e) + o$w))
      }, numeric(1))
      audit$max_dev_homogeneity <- max(hom)
      audit$max_dev_cournot     <- max(cou)
      if (max(hom) > 1e-8 || max(cou) > 1e-8)
        stop("AUDIT FAIL: cross-price identities (homogeneity ",
             format(max(hom)), ", Cournot ", format(max(cou)), ")",
             call. = FALSE)
    }
  }

  ## ------------------------------------------------------------ per -------
  if (per != "cu") {
    div <- if (per == "capita") gl$persons_bar else gl$eqsc_bar
    out$gamma <- out$gamma / div[gI];  out$x <- out$x / div[gI]
    gl$M_bar <- gl$M_bar / div; gl$Gamma <- gl$Gamma / div; gl$SUP <- gl$SUP / div
  }
  audit$per <- per

  res <- list(par = out, cells = gl, audit = audit)
  if (!is.null(cross)) res$cross <- cross

  cat(sprintf(
    "les_aggregate: %d output cells x %d goods | max|sum beta - 1| = %.2e | level repro = %.2e\n",
    nrow(gl), length(unique(out$COM)), audit$max_dev_addup,
    audit$level_repro_rel))
  cat(sprintf(
    "  honesty: %d native x<=0 rows absorbed | mass-wt share_ipf up to %.3f | per = %s\n",
    audit$n_neg_absorbed, max(gl$share_ipf), per))

  if (!is.null(file)) write_les_outputs(res, file, cross_price)
  invisible(res)
}
