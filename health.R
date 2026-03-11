library(tidyverse)

dummy <- function(x, ...) {
  values <- list(...)
  x %in% values + 0
}

ccaa_codes = tribble(
  ~from, ~to,
  "01", "AND",
  "02", "ARA",
  "03", "AST",
  "04", "BAL",
  "05", "CAN",
  "06", "CNT",
  "07", "CYL",
  "08", "CLM",
  "09", "CAT",
  "10", "VAL",
  "11", "EXT",
  "12", "GAL",
  "13", "MAD",
  "14", "MUR",
  "15", "NAV",
  "16", "PVA",
  "17", "RIO",
  "18", "CEU",
  "19", "MEL")

db <- readRDS("./raw/adults.rds") |>
  left_join(readRDS("./raw/hh_common.rds"), by = join_by(id, CCAA, year)) |>
  left_join(readRDS("./raw/individuals.rds"), by = join_by(id, NORDEN, year, SEXO)) |>
  filter_out(when_any(B8 %in% c("98", "99"),
                      E1 %in% c("8", "9"),
                      NIVEST == "99",
                      EDAD.x != EDAD.y)) |>
  rename(EDAD = EDAD.x) |>
  select(-c(EDAD.y, A10))

adults <- db |>
  mutate(age = EDAD,
         woman = dummy(SEXO, 2),
         ccaa = recode_values(CCAA,
                              from = ccaa_codes$from,
                              to = ccaa_codes$to),
         ed_none = dummy(NIVEST, "02", "03"),
         ed_prim = dummy(NIVEST, "04"),
         ed_sec = dummy(NIVEST, "05", "06", "07", "08"),
         ed_sup = dummy(NIVEST, "09"),
         a_working = dummy(A11, "1"),
         a_unempl = dummy(A11, "2"),
         a_retired = dummy(A11, "3"),
         a_student = dummy(A11, "4"),
         a_disabled = dummy(A11, "5"),
         a_house = dummy(A11, "6"),
         a_other = dummy(A11, "7"),
         b_public = dummy(B8, "01"),
         b_temp = dummy(B8, "03"),
         b_perm = dummy(B8, "01", "02"),
         b_employer = dummy(B8, "05"),
         b_self = dummy(B8, "06"),
         b_other = dummy(B8, "04", "07", "08", "09"),
         e_absence = dummy(E1, "1"),
         e_absence_days = replace_values(E2, NA ~ 0))

# Number of adults by year and sex
adults |>
  distinct(id, .keep_all = TRUE) |>
  count(year, woman)

adults |>
  summarise(public = mean(b_public),
            temp = mean(b_temp),
            perm = mean(b_perm),
            employer = mean(b_employer),
            self = mean(b_self),
            other = mean(b_other),
            absence = mean(e_absence),
            absence_days = mean(e_absence_days),
            .by = year)

adults |>
  summarise(none = mean(ed_none),
            prim = mean(ed_prim),
            sec = mean(ed_sec),
            sup = mean(ed_sup),
            .by = year)


adults |>
  count(year, NIVEST) |>
  print(n = 50)
