# correspond.R -- internal: parse and validate the three correspondence maps.
# Contract (spec 073, "The correspondence contract" + AC5):
#   goods     claims native key `good`
#   regions   claims native key `state`
#   household claims `decile`, `age`, optionally `state`, optionally `fam`
# A native dimension claimed by two maps is an error. Every native element
# must map to exactly one output element: zero or duplicate mappings are
# errors that NAME the offenders. Nothing is renormalised silently.

.map_keys <- list(goods     = "good",
                  regions   = "state",
                  household = c("decile", "age", "state", "fam"))

# Accepts: path to CSV (comment lines start with '#'), data.frame, or a named
# vector/list (names = native elements of the single default key).
read_map <- function(x, dim_name) {
  keys <- .map_keys[[dim_name]]
  if (is.character(x) && length(x) == 1L && file.exists(x))
    x <- utils::read.csv(x, comment.char = "#", stringsAsFactors = FALSE)
  if (!is.data.frame(x)) {
    if (is.null(names(x)) || any(!nzchar(names(x))))
      stop("`", dim_name, "` must be a CSV path, a data.frame, or a fully ",
           "named vector/list (names = native ", keys[[1L]], ")",
           call. = FALSE)
    x <- data.frame(k = names(x), out = unname(unlist(x)),
                    stringsAsFactors = FALSE)
    names(x)[1L] <- keys[[1L]]
  }
  claimed <- intersect(names(x), keys)
  outcol  <- setdiff(names(x), keys)
  if (length(claimed) < 1L)
    stop("`", dim_name, "` map claims no native key; allowed: ",
         paste(keys, collapse = ", "), call. = FALSE)
  if (length(outcol) != 1L)
    stop("`", dim_name, "` map needs exactly one output column besides the ",
         "native key(s); found: ",
         if (length(outcol)) paste(outcol, collapse = ", ") else "none",
         call. = FALSE)
  x[[outcol]] <- as.character(x[[outcol]])
  if (anyNA(x[[outcol]]) || any(!nzchar(x[[outcol]])))
    stop("`", dim_name, "` map has empty output labels", call. = FALSE)
  list(dim = dim_name, keys = claimed, out = outcol, table = x)
}

# Cross-map validation: no native dimension claimed twice.
check_claims <- function(maps) {
  maps <- Filter(Negate(is.null), maps)
  all_keys <- unlist(lapply(maps, `[[`, "keys"))
  dup <- unique(all_keys[duplicated(all_keys)])
  if (length(dup))
    stop("native dimension(s) claimed by more than one map: ",
         paste(dup, collapse = ", "), call. = FALSE)
  invisible(maps)
}

# Apply one map to the native table `df`: returns the output labels, erroring
# on unmapped or multiply-mapped native elements (AC5).
apply_map <- function(map, df) {
  key_df <- unique(df[map$keys])
  tab <- map$table
  tab_key <- do.call(paste, c(tab[map$keys], sep = "\r"))
  if (anyDuplicated(tab_key)) {
    off <- unique(tab_key[duplicated(tab_key)])
    stop("`", map$dim, "` map assigns more than one output to native ",
         "element(s): ", paste(gsub("\r", " x ", utils::head(off, 10L)),
                               collapse = "; "),
         if (length(off) > 10L) " ..." else "", call. = FALSE)
  }
  df_key  <- do.call(paste, c(df[map$keys],  sep = "\r"))
  uni_key <- do.call(paste, c(key_df[map$keys], sep = "\r"))
  hit <- match(uni_key, tab_key)
  if (anyNA(hit)) {
    off <- uni_key[is.na(hit)]
    stop("`", map$dim, "` map leaves native element(s) unmapped: ",
         paste(gsub("\r", " x ", utils::head(off, 10L)), collapse = "; "),
         if (length(off) > 10L) paste0(" ... (", length(off), " total)") else "",
         call. = FALSE)
  }
  tab[[map$out]][match(df_key, tab_key)]
}
