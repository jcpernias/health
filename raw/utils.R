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

#' Read and validate the selected survey years
#'
#' @param path A character string giving the configuration file path.
#'   Defaults to `"./years.txt"`.
#'
#' @return An integer vector of selected years, in file order.
#'
#' @details The file must contain at least one year, with exactly one of
#'   2014, 2017, 2020 or 2023 per line, without a header, blank lines or
#'   duplicates. Invalid input or an unreadable file raises an error.
#'
#' @examples
#' path <- tempfile()
#' writeLines(c("2014", "2020", "2023"), path)
#' read_years(path)
#' unlink(path)
#'
#' @export
read_years <- function(path = "./years.txt") {
  years <- readLines(path, warn = FALSE)
  valid_years <- c("2014", "2017", "2020", "2023")

  if (length(years) == 0L ||
        anyDuplicated(years) ||
        !all(years %in% valid_years)) {
    stop("Invalid ", path,
      ": specify one valid year per line, without duplicates.", call. = FALSE)
  }

  as.integer(years)
}

#' Read and harmonize one year of fixed-width survey microdata
#'
#' @param year An integer giving the survey year.
#' @param vars A variable mapping tibble with columns `name`, `type` and
#'   `v_YEAR` for the selected year.
#' @param vars_prefix Prefix of the annual layout CSV files, such as
#'   `"adult-vars"` or `"household-vars"`.
#' @param data_prefix Prefix of the compressed microdata files, such as
#'   `"adultos"` or `"hogar"`.
#' @param raw_dir Directory containing the layout and microdata files.
#'
#' @return A tibble with harmonized variable names, `year` and household `id`.
#'   The original `IDENTHOGAR` column is removed.
#'
#' @details Uses `vars_prefix-YEAR.csv` for field positions and lengths and
#'   `data_prefix_YEAR.txt.xz` for the data. Column types come from `vars`.
#'   The household identifier combines `IDENTHOGAR` and the year. Transformations
#'   specific to adults or households remain the caller's responsibility.
#'
#' @export
read_microdata <- function(year, vars, vars_prefix, data_prefix,
                           raw_dir = "./raw") {
  path <- file.path(raw_dir, paste0(vars_prefix, "-", year, ".csv"))
  vars_yr <- vars |>
    dplyr::select(var = dplyr::all_of(paste0("v_", year)), type) |>
    dplyr::left_join(readr::read_csv(path, col_types = "cii-"),
      dplyr::join_by(var)) |>
    dplyr::mutate(end = start + len - 1)

  # Use the same variable names for all years.
  vars_yr$var <- vars$name
  positions <- readr::fwf_positions(start = vars_yr$start,
    end = vars_yr$end, col_names = vars_yr$var)
  types <- do.call(readr::cols, setNames(as.list(vars_yr$type), vars_yr$var))

  readr::read_fwf(file.path(raw_dir, paste0(data_prefix, "_", year, ".txt.xz")),
    col_positions = positions, col_types = types) |>
    dplyr::mutate(year = year, id = glue::glue("{IDENTHOGAR}-{year}")) |>
    dplyr::select(-IDENTHOGAR)
}
