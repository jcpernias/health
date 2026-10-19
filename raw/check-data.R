suppressPackageStartupMessages(library(tidyverse))

# Run from the project root. An optional argument selects another raw directory.
args <- commandArgs(trailingOnly = TRUE)
raw_dir <- if (length(args) == 0L) "./raw" else args[[1L]]

# Read years to be included in the final database
year_config <- read_csv(file.path(raw_dir, "years.csv"), col_types = "ii")
valid_years <- c(2014L, 2017L, 2020L, 2023L)
if (!all(c("year", "include") %in% names(year_config)) ||
    nrow(problems(year_config)) != 0L ||
    anyNA(year_config$year) ||
    !all(year_config$year %in% valid_years)) {
  cat("Invalid years.csv: allowed years are 2014, 2017, 2020 and 2023.\n")
  quit(status = 1L)
}
if (anyDuplicated(year_config$year) ||
    anyNA(year_config$include) ||
    !all(year_config$include %in% c(0L, 1L)) ||
    !any(year_config$include == 1L)) {
  cat("Invalid years.csv: years must be unique, include must be 0 or 1, and at least one year must be selected.\n")
  quit(status = 1L)
}
years <- year_config |>
  filter(include == 1) |>
  pull(year)

# Compute md5sums
files <-
  pmap(expand_grid(x = c("adultos", "hogar"), y = years),
    \(x, y) paste0(x, "_", y, ".txt.xz")) |>
  unlist()

sums <- tools::md5sum(file.path(raw_dir, files))
not_found <- is.na(sums)
if (any(not_found)) {
  cat(paste0("Missing files: ",
    paste0(files[not_found], collapse = ", "),
    ".\n"))
  quit(status = 1L)
}

actual_sums <- tibble(file = files, actual_md5 = sums)

# Read expected md5sums
expected <- read_csv(file.path(raw_dir, "checksums.csv"),
  col_types = "cc")

# Compare actual an expected md5sums
comp <- actual_sums |>
  left_join(expected, by = join_by(file)) |>
  filter_out(actual_md5 == md5)

# Fail if md5sums differ
if (nrow(comp) != 0) {
  print(comp)
  quit(status = 1L)
}
