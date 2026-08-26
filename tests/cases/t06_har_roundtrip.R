# t06 -- AC7: illegal GEMPACK names are rejected before write_har; a legal
# write round-trips through HARr::read_har with headers and sets intact.
les <- les_data()
rdmap <- function(f) utils::read.csv(corr_file(f), comment.char = "#")
g16 <- rdmap("goods_42_to_16.csv")
r4  <- rdmap("regions_51_to_4.csv")
hq  <- rdmap("household_decile_to_quintile.csv")

# 1. illegal element label (13 chars) rejected, named
bad <- g16; bad$COM <- "THIRTEEN_CHR_X"
msg <- tryCatch({
  les_aggregate(goods = bad, regions = r4, household = hq,
                file = tempfile()); NULL
}, error = function(e) conditionMessage(e))
stopifnot(!is.null(msg), grepl("illegal GEMPACK", msg),
          grepl("THIRTEEN_CHR_X", msg))
cat("  ok: illegal element label rejected by name\n")

# 2. legal write + read_har round trip
tf <- tempfile()
res <- les_aggregate(goods = g16, regions = r4, household = hq,
                     file = tf, cross_price = TRUE)
stopifnot(file.exists(paste0(tf, ".har")),
          file.exists(paste0(tf, ".csv")),
          file.exists(paste0(tf, "_cells.csv")))
har <- HARr::read_har(paste0(tf, ".har"))
nm <- tolower(c("BETA", "GAMM", "XEXP", "WSHR", "ETA", "EOWN",
                "FRSC", "SUBS", "MEXP", "NCU", "ECRS"))
stopifnot(all(nm %in% tolower(names(har))))
B <- har[[which(tolower(names(har)) == "beta")]]
key <- cbind(toupper(res$par$COM), toupper(res$par$REG), toupper(res$par$HH))
dimnames(B) <- lapply(dimnames(B), toupper)
dev <- max(abs(B[key] - res$par$beta))
stopifnot(dev <= 1e-6)  # .har stores 4-byte reals; exactness lives in the CSV
cat(sprintf(
  "t06 PASS: 11 headers round-trip; max beta dev vs .har %.1e (4-byte float)\n",
  dev))
