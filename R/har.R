# har.R -- internal: GEMPACK name validation and the .har/.csv writers.
# AC7: header names <= 4 chars; set names <= 12; element labels <= 12 and
# [A-Za-z][A-Za-z0-9_]*. Illegal names are REJECTED with a message naming
# the offenders -- nothing is silently renamed.

check_gempack_elements <- function(x, what) {
  x <- unique(as.character(x))
  bad <- x[!grepl("^[A-Za-z][A-Za-z0-9_]{0,11}$", x)]
  if (length(bad))
    stop("illegal GEMPACK element name(s) in ", what, ": ",
         paste(utils::head(bad, 10L), collapse = ", "),
         if (length(bad) > 10L) " ..." else "",
         ". Element labels must be [A-Za-z][A-Za-z0-9_]* and at most 12 ",
         "characters; fix the output labels in your correspondence.",
         call. = FALSE)
  x
}

les_array <- function(df, value, dims) {
  lev <- lapply(dims, function(d) unique(df[[d]]))
  names(lev) <- dims
  arr <- array(0, dim = vapply(lev, length, 1L), dimnames = lev)
  arr[as.matrix(df[dims])] <- df[[value]]
  arr
}

write_les_outputs <- function(res, file, cross_price = FALSE) {
  out <- res$par; gl <- res$cells
  com <- check_gempack_elements(out$COM, "goods output (COM)")
  reg <- check_gempack_elements(out$REG, "regions output (REG)")
  hht <- check_gempack_elements(out$HH,  "household output (HH)")

  # NA (renormalized eta/eps) cannot ride in a .har: write 0 and say so.
  har_par <- out
  n_na <- sum(is.na(har_par$eta)) + sum(is.na(har_par$eps_own))
  if (n_na)
    warning(".har cannot carry NA: ", n_na, " renormalized eta/eps values ",
            "written as 0 (flagged rows; see the CSV for the NA).",
            call. = FALSE)
  har_par$eta[is.na(har_par$eta)] <- 0
  har_par$eps_own[is.na(har_par$eps_own)] <- 0

  d3 <- c("COM", "REG", "HH"); d2 <- c("REG", "HH")
  har <- list(
    BETA = les_array(har_par, "beta",    d3),
    GAMM = les_array(har_par, "gamma",   d3),
    XEXP = les_array(har_par, "x",       d3),
    WSHR = les_array(har_par, "w",       d3),
    ETA  = les_array(har_par, "eta",     d3),
    EOWN = les_array(har_par, "eps_own", d3),
    FRSC = les_array(gl, "phi",   d2),
    SUBS = les_array(gl, "Gamma", d2),
    MEXP = les_array(gl, "M_bar", d2),
    NCU  = les_array(gl, "N_cu",  d2))
  if (cross_price && !is.null(res$cross)) {
    cr <- res$cross
    cr$eps[is.na(cr$eps)] <- 0
    lev <- list(COM_g = unique(cr$COM_g), COM_j = unique(cr$COM_j),
                REG = unique(cr$REG), HH = unique(cr$HH))
    arr <- array(0, dim = vapply(lev, length, 1L), dimnames = lev)
    arr[as.matrix(cr[c("COM_g", "COM_j", "REG", "HH")])] <- cr$eps
    har$ECRS <- arr
  }
  stopifnot(all(nchar(names(har)) <= 4L))
  HARr::write_har(har, paste0(file, ".har"))

  utils::write.csv(out, paste0(file, ".csv"), row.names = FALSE)
  utils::write.csv(gl,  paste0(file, "_cells.csv"), row.names = FALSE)
  cat("wrote ", file, ".har / .csv / _cells.csv\n", sep = "")
  invisible(file)
}
