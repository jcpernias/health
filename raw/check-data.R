suppressPackageStartupMessages(library(tidyverse))

# Run from the project root. An optional argument selects another raw directory.
args <- commandArgs(trailingOnly = TRUE)
raw_dir <- if (length(args) == 0L) "./raw" else args[[1L]]

#' Decompress an XZ file
#'
#' @param file A character string giving the path to an XZ-compressed file.
#' @param path A character string giving the output path. If `NULL` (the
#'   default), a temporary file is created.
#'
#' @return The path to the created file, or `NA_character_` if decompression
#'   fails. The caller is responsible for removing the file after use.
#'
#' @details Decompresses in 1 MiB blocks without loading the entire content
#'   into memory. Connections are closed before returning. Warnings are treated
#'   as errors, and an incomplete output file is removed on failure.
#'   An existing file at `path` is overwritten.
#'
#' @examples
#' source <- tempfile(fileext = ".xz")
#' con <- xzfile(source, open = "wb")
#' writeBin(charToRaw("Example data"), con)
#' close(con)
#' unpacked <- decompress_xz(source)
#' unlink(c(source, unpacked))
#'
#' @export
decompress_xz <- function(file, path = NULL) {
  tryCatch(
    # local() ejecuta la limpieza antes de que tryCatch devuelva NA.
    withCallingHandlers(local({
      if (is.null(path)) path <- tempfile()
      complete <- FALSE

      input <- xzfile(file, open = "rb")
      on.exit(close(input), add = TRUE)
      output <- base::file(path, open = "wb")
      on.exit(if (!complete) unlink(path), add = TRUE)
      tryCatch({
        repeat {
          chunk <- readBin(input, what = "raw", n = 1024L * 1024L)
          if (length(chunk) == 0L) break
          writeBin(chunk, output)
        }
      }, finally = close(output))

      complete <- TRUE
      path
    }), warning = function(w) stop(conditionMessage(w), call. = FALSE)),
    error = function(e) NA_character_
  )
}

#' Compute the MD5 checksum of an XZ file's uncompressed content
#'
#' @param path A character string giving the path to an XZ-compressed file.
#'
#' @return An unnamed character string containing the MD5 checksum of the
#'   uncompressed bytes, or `NA_character_` if the calculation fails.
#'
#' @details Uses [decompress_xz()] to decompress into a temporary file, which
#'   is removed on exit, including when an error occurs. Errors are caught and
#'   return `NA_character_`, allowing the caller to continue processing other
#'   files and report failures later. Recompressing identical bytes preserves
#'   the checksum.
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
  tryCatch(
    withCallingHandlers(local({
      unpacked <- decompress_xz(path)
      if (is.na(unpacked)) return(NA_character_)
      on.exit(unlink(unpacked), add = TRUE)

      unname(tools::md5sum(unpacked))
    }), warning = function(w) stop(conditionMessage(w), call. = FALSE)),
    error = function(e) NA_character_
  )
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


# Combinar cada año seleccionado con los archivos de adultos y hogares.
fnames <-
  pmap(expand_grid(x = c("adultos", "hogar"), y = years),
    \(x, y) paste0(x, "_", y, ".txt.xz")) |>
  unlist()

paths <- file.path(raw_dir, fnames)
# Si falta algún archivo, no merece la pena continuar: detener Make antes
# de calcular huellas o modificar el caché.
not_found <- !file.exists(paths)
if (any(not_found)) {
  cat(paste0("Missing files: ",
    paste0(fnames[not_found], collapse = ", "),
    ".\n"))
  quit(status = 1L)
}
mtime <- file.mtime(paths)

files <- tibble(file = fnames, path = paths, mtime = mtime)

#' Read and refresh the local checksum cache
#'
#' @param files A tibble with columns `file` (name), `path` (source path) and
#'   `mtime` (source modification time, POSIXct). Files must already exist.
#' @param raw_dir Directory containing `checksums-local.csv`.
#'
#' @return A tibble with columns `file`, `md5_local` and `md5_time`.
#'
#' @details Recalculates missing checksums or timestamps and checksums older
#'   than the source file. Writes the cache only when calculations are needed.
#'   Failed calculations produce NA checksums; valid results are saved before
#'   terminating the R process with status 1. Reference checksums are checked
#'   separately by the caller.
read_cache <- function(files, raw_dir) {
  f_error <- FALSE

  # Mantener los mismos tipos al leer el CSV o crear el caché vacío.
  inner_read <- function(path) {
    if (!file.exists(path)) {
      tbl <- tibble(file = character(0), md5_local = character(0),
        md5_time = POSIXct(0))
      return(tbl)
    }
    # Dos columnas de texto y una fecha con hora.
    read_csv(path, col_types = "ccT")
  }

  local_cache_path <- file.path(raw_dir, "checksums-local.csv")
  local_cache <- inner_read(local_cache_path)

  # El join conserva los archivos seleccionados; las entradas nuevas quedan NA.
  # Recalcular si falta el MD5 o la fecha, o si el archivo es posterior.
  files_cache <- left_join(files, local_cache, by = join_by(file)) |>
    mutate(update = is.na(md5_local) | is.na(md5_time) | mtime > md5_time)

  if(any(files_cache$update)) {
    # pmap procesa cada pareja nombre-ruta; bind_rows reúne sus resultados.
    # now() fecha el intento; un MD5 ausente basta para detectar un fallo.
    updated_cache <-
      pmap(files_cache |> filter(update) |> select(file, path),
        \(file, path) tibble(file = file, md5_local = md5_uncompressed(path),
          md5_time = now())) |>
      bind_rows()

    # Reutilizar las filas vigentes y añadir las recién calculadas.
    new_cache <-
      files_cache |>
      filter(!update) |>
      select(file, md5_local, md5_time) |>
      bind_rows(updated_cache)

    # Mostrar los fallos y excluirlos del CSV para reintentarlos en otra ejecución.
    if(anyNA(new_cache)) {
      print(new_cache)
      f_error <- TRUE
      new_cache <- drop_na(new_cache)
    }
    # Guardar los resultados válidos aunque haya fallos en otros archivos.
    write_csv(new_cache, file = local_cache_path)
    local_cache <- new_cache

    # Si flag_error está activo, terminar con código de error para detener Make.
    if(f_error) {
      quit(status = 1L)
    }
  }
  local_cache
}

# Read expected MD5s of the uncompressed content
expected <- read_csv(file.path(raw_dir, "checksums.csv"),
  col_types = "cc")

# Partir de files limita la comparación a los archivos seleccionados.
# filter_out conserva también los NA para detectar referencias ausentes.
comp <- files |>
  left_join(read_cache(files, raw_dir), by = join_by(file)) |>
  left_join(expected, by = join_by(file)) |>
  filter_out(md5_local == md5)

# Fail if md5sums differ
if (nrow(comp) != 0) {
  print(comp)
  quit(status = 1L)
}
