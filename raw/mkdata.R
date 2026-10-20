library(dplyr)
library(purrr)
library(readr)
library(glue)

source("./raw/utils.R")

# Read years to be included in the final database
years <- read_years()

adult_vars <- read_csv("./raw/adult-vars.csv",
                           col_types = "cccccci")

# Read adult data for a given year
adult_yr <- function(year, adult_vars) {
  read_microdata(year, adult_vars, "adult-vars", "adultos") |>
    mutate(CMD1 = CMD1 / 100)
}

# Read adult data for all years
adult_db <- map(years, \(x) adult_yr(x, adult_vars)) |>
  bind_rows()

# Number of adults by year
adult_db |>
  distinct(id, .keep_all = TRUE) |>
  count(year)

saveRDS(adult_db, file = "./raw/adults.rds", compress = "xz")

household_vars <- read_csv("./raw/household-vars.csv",
                           col_types = "cccccci")

# Read household data for a given year
household_yr <- function(year, hh_vars) {
  read_microdata(year, hh_vars, "household-vars", "hogar")
}

# Read household data for all years
household_db <- map(years, \(x) household_yr(x, household_vars)) |>
  bind_rows()

# Extract common variables across household members
household_common <-
  local({
    # Drop redundant records and recode NAs
    db <- household_db |>
      select(-c(SEXO, EDAD, NORDEN, A10, A11)) |>
      distinct() |>
      mutate(INGRESOS = replace_values(INGRESOS, c("98", "99") ~ NA),
             CLASE_PR = replace_values(CLASE_PR, "9" ~ NA))

    # Count records and missing values in a single summary per household.
    hh_summary <- db |>
      group_by(id) |>
      summarise(
        n = n(),
        na_inc = sum(is.na(INGRESOS)),
        na_class = sum(is.na(CLASE_PR)),
        .groups = "drop"
      )

    db |>
      left_join(hh_summary, join_by(id)) |>
      filter_out(when_any(n == 2 & na_inc == 1 & is.na(INGRESOS),
                          n == 2 & na_class == 1 & is.na(CLASE_PR))) |>
      select(-c(n, na_class, na_inc))
  })

# Variables for family members
individuals_db <- household_db |>
  select(SEXO, EDAD, NORDEN, A10, A11, id, year) |>
  mutate(A10 = replace_values(A10, c("98", "99") ~ NA),
         A11 = replace_values(A11, "9" ~ NA))

saveRDS(individuals_db, file = "./raw/individuals.rds", compress = "xz")
saveRDS(household_common, file = "./raw/hh_common.rds", compress = "xz")
