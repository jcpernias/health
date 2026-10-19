suppressPackageStartupMessages(library(tidyverse))

# Run from the project root. An optional argument selects another raw directory.
args <- commandArgs(trailingOnly = TRUE)
raw_dir <- if (length(args) == 0L) "./raw" else args[[1L]]

#' Compute the MD5 checksum of an XZ file's uncompressed content
#'
#' @param path A character string giving the path to an XZ-compressed file.
#'
#' @return An unnamed character string containing the MD5 checksum of the
#'   uncompressed bytes.
#'
#' @details The file is decompressed in 1 MiB blocks into a temporary file,
#'   without loading the entire content into memory. The temporary file is
#'   removed on exit, including when an error occurs. Decompression warnings
#'   are treated as errors. Recompressing identical bytes preserves the checksum.
#'
#' @examples
#' path <- tempfile(fileext = ".xz")
#' con <- xzfile(path, open = "wb")
#' writeBin(charToRaw("Example data"), con)
#' close(con)
#' md5_uncompressed(path)
#' unlink(path)
#'
#' @export
md5_uncompressed <- function(path) {
  unpacked <- tempfile()
  on.exit(unlink(unpacked), add = TRUE)

  input <- xzfile(path, open = "rb")
  on.exit(close(input), add = TRUE)
  output <- file(unpacked, open = "wb")
  tryCatch(
    withCallingHandlers({
      repeat {
        chunk <- readBin(input, what = "raw", n = 1024L * 1024L)
        if (length(chunk) == 0L) break
        writeBin(chunk, output)
      }
    }, warning = function(w) stop(conditionMessage(w), call. = FALSE)),
    finally = close(output)
  )

  unname(tools::md5sum(unpacked))
}

# Read years to be included in the final database
year_config <- read_csv("./years.csv",
  col_types = "ii")

# Check years.csv is valid
valid_years <- c(2014L, 2017L, 2020L, 2023L)

if (anyNA(year_config) ||
      anyDuplicated(year_config$year) ||
      !all(year_config$year %in% valid_years) ||
      !all(year_config$include %in% c(0L, 1L)) ||
      all(year_config$include == 0L)) {
  print(year_config)
  quit(status = 1L)
}

years <- year_config |>
  filter(include == 1) |>
  pull(year)


# Select compressed source files
files <-
  pmap(expand_grid(x = c("adultos", "hogar"), y = years),
    \(x, y) paste0(x, "_", y, ".txt.xz")) |>
  unlist()

paths <- file.path(raw_dir, files)
not_found <- !file.exists(paths)
if (any(not_found)) {
  cat(paste0("Missing files: ",
    paste0(files[not_found], collapse = ", "),
    ".\n"))
  quit(status = 1L)
}

sums <- map_chr(paths, md5_uncompressed)
actual_sums <- tibble(file = files, actual_md5 = sums)

# Read expected MD5s of the uncompressed content
expected <- read_csv(file.path(raw_dir, "checksums.csv"),
  col_types = "cc")

# Compare actual and expected MD5s
comp <- actual_sums |>
  left_join(expected, by = join_by(file)) |>
  filter_out(actual_md5 == md5)

# Fail if md5sums differ
if (nrow(comp) != 0) {
  print(comp)
  quit(status = 1L)
}
