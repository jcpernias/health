source("./raw/mkdata-common.R")

adult_vars <- read_csv("./raw/adult-vars.csv",
                           col_types = "cccccci")

# Read household data for a given year
adult_yr <- function(year, adult_vars) {
  # Get position of variables in th households data files
  path <- glue("./raw/adult-vars-{year}.csv")
  vars_yr <- adult_vars |>
    select(var = all_of(glue("v_{year}")), type) |>
    left_join(read_csv(path, col_types = "cii-"), join_by(var)) |>
    mutate(end = start + len - 1)

  # Use the same variable names for all years
  vars_yr$var <- adult_vars$name

  # Read the data
  positions <- fwf_positions(start = vars_yr$start,
                             end = vars_yr$end,
                             col_names = vars_yr$var)
  types <- do.call(cols, setNames(as.list(vars_yr$type), vars_yr$var))
  read_fwf(file.path(raw_data_path, glue("adultos_{year}.txt.xz")),
           col_positions = positions,
           col_types = types) |>
    mutate(year = year, id = glue("{IDENTHOGAR}-{year}")) |>
    select(-IDENTHOGAR) |>
    mutate(CMD1 = CMD1 / 100)
}

# Read household data for all years
adult_db <- map(years, \(x) adult_yr(x, adult_vars)) |>
  bind_rows()

# Number of adults by year
adult_db |>
  distinct(id, .keep_all = TRUE) |>
  count(year)

saveRDS(adult_db, file = "./raw/adults.rds", compress = "xz")

