suppressPackageStartupMessages(library(tidyverse))

# Run from the project root. An optional argument selects another raw directory.
args <- commandArgs(trailingOnly = TRUE)
raw_dir <- if (length(args) == 0L) "./raw" else args[[1L]]

source("./raw/utils.R")

years <- read_years()


# Combinar cada año seleccionado con los archivos de adultos y hogares.
fnames <- expand_grid(
  type = c("adultos", "hogar"),
  year = years
) |>
  mutate(file = paste0(type, "_", year, ".txt.xz")) |>
  pull(file)

paths <- file.path(raw_dir, fnames)
# Si falta algún archivo, no merece la pena continuar: detener Make antes
# de calcular huellas.
not_found <- !file.exists(paths)
if (any(not_found)) {
  cat(paste0("Missing files: ",
    paste0(fnames[not_found], collapse = ", "),
    ".\n"))
  quit(status = 1L)
}
files <- tibble(file = fnames, path = paths)

# Read expected MD5s of the uncompressed content
expected <- read_csv(file.path(raw_dir, "checksums.csv"),
  col_types = "cc")

# Partir de files limita la comparación a los archivos seleccionados.
# filter_out conserva también los NA para detectar referencias ausentes.
comp <- files |>
  mutate(md5_local = map_chr(path, md5_uncompressed)) |>
  left_join(expected, by = join_by(file)) |>
  filter_out(md5_local == md5)

# Identify failures, including unreadable data and missing references.
if (nrow(comp) != 0) {
  cat("Microdata validation failed:\n")
  comp |>
    mutate(problem = case_when(
      is.na(md5) ~ "Missing reference checksum",
      is.na(md5_local) ~ "Cannot decompress or calculate checksum",
      .default = "Checksum mismatch"
    )) |>
    select(file, problem, md5_local, md5) |>
    print(n = Inf, width = Inf)
  quit(status = 1L)
}
