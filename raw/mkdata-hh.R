source("./raw/mkdata-common.R")

household_vars <- read_csv("./raw/household-vars.csv",
                           col_types = "cccccci")


# Read household data for a given year
household_yr <- function(year, hh_vars) {
  # Get position of variables in th households data files
  path <- glue("./raw/household-vars-{year}.csv")
  vars_yr <- hh_vars |>
    select(var = all_of(glue("v_{year}")), type) |>
    left_join(read_csv(path, col_types = "cii-"), join_by(var)) |>
    mutate(end = start + len - 1)

  # Use the same variable names for all years
  vars_yr$var <- hh_vars$name

  # Read the data
  positions <- fwf_positions(start = vars_yr$start,
                             end = vars_yr$end,
                             col_names = vars_yr$var)
  types <- do.call(cols, setNames(as.list(vars_yr$type), vars_yr$var))
  read_fwf(file.path(raw_data_path, glue("hogar_{year}.txt.xz")),
           col_positions = positions,
           col_types = types) |>
    mutate(year = year, id = glue("{IDENTHOGAR}-{year}")) |>
    select(-IDENTHOGAR)
}

# Read household data for all years
household_db <- map(years, \(x) household_yr(x, household_vars)) |>
  bind_rows()

# Number of households by year
household_db |>
  distinct(id, .keep_all = TRUE) |>
  count(year)

# Extract common variables across household members
household_common <-
  local({
    # Drop redundant records and recode NAs
    db <- household_db |>
      select(-c(SEXO, EDAD, A10, A11)) |>
      distinct() |>
      mutate(INGRESOS = replace_values(INGRESOS, c("98", "99") ~ NA),
             CLASE_PR = replace_values(CLASE_PR, "9" ~ NA))

    # Find households with more than one record
    reps <- db |> count(id)

    # Find households with NAs
    na_inc <- db |>
      group_by(id) |>
      summarise(na_inc = sum(is.na(INGRESOS)))

    na_class <- db |>
      group_by(id) |>
      summarise(na_class = sum(is.na(CLASE_PR)))

    db |>
      left_join(reps, join_by(id)) |>
      left_join(na_inc, join_by(id)) |>
      left_join(na_class, join_by(id)) |>
      filter_out(when_any(n == 2 & na_inc == 1 & is.na(INGRESOS),
                          n == 2 & na_class == 1 & is.na(CLASE_PR))) |>
      select(-c(n, na_class, na_inc))
  })

# Variables for family members
individuals_db <- household_db |>
  select(SEXO, EDAD, A10, A11, id, year) |>
  mutate(A10 = replace_values(A10, c("98", "99") ~ NA),
         A11 = replace_values(A11, "9" ~ NA))

saveRDS(individuals_db, file = "./raw/individuals.rds", compress = "xz")
saveRDS(household_common, file = "./raw/hh_common.rds", compress = "xz")
