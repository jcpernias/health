library(tidyverse)
library(writexl)

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
  filter_out(EDAD.x != EDAD.y) |>
  rename(EDAD = EDAD.x) |>
  select(-c(EDAD.y, A10)) |>
  mutate(age = EDAD,
         woman = dummy(SEXO, "2"),
         partner = recode_values(A4,
                                 c("1", "2") ~ 1,
                                 "3" ~ 0),
         native = dummy(A2a_1, "1"),
         nadults = NADULTOS,
         nchildren = NMENORES,
         hh_size = nadults + nchildren,
         hh_a = dummy(A12, "1"),
         hh_b = dummy(A12, "2"),
         hh_c = dummy(A12, "3"),
         hh_d = dummy(A12, "4"),
         hh_e = dummy(A12, "5"),
         hh_f = dummy(A12, "6"),
         hh_g = dummy(A12, "7"),
         hh_h = dummy(A12, "8"),
         ccaa = recode_values(CCAA,
                              from = ccaa_codes$from,
                              to = ccaa_codes$to),
         urb_high = dummy(ESTRATO, "0", "1", "2", "3"),
         urb_med = dummy(ESTRATO, "4", "5"),
         urb_low = dummy(ESTRATO, "6"),
         ed_none = recode_values(NIVEST, c("02", "03") ~ 1,
                                 "99" ~ NA, default = 0),
         ed_prim = recode_values(NIVEST, "04" ~ 1, "99" ~ NA, default = 0),
         ed_sec = recode_values(NIVEST, c("05", "06", "07", "08") ~ 1,
                                "99" ~ NA, default = 0),
         ed_sup = recode_values(NIVEST, "09" ~ 1, "99" ~ NA, default = 0),
         a_working = dummy(A11, "1"),
         a_unempl = dummy(A11, "2"),
         a_retired = dummy(A11, "3"),
         a_student = dummy(A11, "4"),
         a_disabled = dummy(A11, "5"),
         a_house = dummy(A11, "6"),
         a_other = dummy(A11, "7"),
         b_public = recode_values(B8, "01" ~ 1,
                                  c("98", "99", NA) ~ NA, default = 0),
         b_temp = recode_values(B8, "03" ~ 1,
                                c("98", "99", NA) ~ NA, default = 0),
         b_perm = recode_values(B8, c("01", "02") ~ 1,
                                c("98", "99", NA) ~ NA, default = 0),
         b_employer = recode_values(B8, "05" ~ 1,
                                    c("98", "99", NA) ~ NA, default = 0),
         b_self = recode_values(B8, "06" ~ 1,
                                c("98", "99", NA) ~ NA, default = 0),
         b_other = recode_values(B8, c("04", "07", "08", "09") ~ 1,
                                 c("98", "99", NA) ~ NA, default = 0),
         b_fulltime = recode_values(B11, "1" ~ 1, "2" ~ 0),
         b_parttime = recode_values(B11, "1" ~ 0, "2" ~ 1),
         b_shift = recode_values(B12,
                                 c("06", "07", "08") ~ 1,
                                 c("01", "02", "03", "04", "05") ~ 0),
         c_health_status = as.integer(C1),
         c_chronic = recode_values(C2, "1" ~ 1, "2" ~ 0),
         c_severe_limit = recode_values(C3a, "1" ~ 1, c("2", "3") ~ 0),
         c_moderate_limit = recode_values(C3a, "2" ~ 1, c("1", "3") ~ 0),
         c_no_limit = recode_values(C3a, "3" ~ 1, c("1", "2") ~ 0),
         c_physical_limit = recode_values(C3b, "1" ~ 1, c("8", "9") ~ NA,
                                          default = 0),
         c_mental_limit = recode_values(C3b, "2" ~ 1, c("8", "9") ~ NA,
                                        default = 0),
         c_both_limit = recode_values(C3b, "3" ~ 1, c("8", "9") ~ NA,
                                      default = 0),
         e_absence = recode_values(E1, "1" ~ 1, c("8", "9", NA) ~ NA,
                                    default = 0),
         e_absence_days = replace_values(E2, NA ~ 0),
         o_sedentary_work =
           recode_values(O1, "1" ~ 1, c("5", "8", "9") ~ NA, default = 0) *
           replace_values(a_working, 0 ~ NA),
         o_sedentary_leisure = recode_values(O2, "1" ~ 1, c("8", "9") ~ NA,
                                             default = 0),
         q_smoker = recode_values(Q1, "1" ~ 1,  c("8", "9") ~ NA,
                                  default = 0),
         q_cigs = replace_values(Q2, NA ~ 0, 98:99 ~ NA),
         bmi_low = recode_values(IMC, "1" ~ 1, "9" ~ NA, default = 0),
         bmi_med = recode_values(IMC, c("2", "3") ~ 1, "9" ~ NA, default = 0),
         bmi_high = recode_values(IMC, "4" ~ 1, "9" ~ NA, default = 0),
         alcohol = replace_values(CMD1, 9.99 ~ NA),
         depress_severity = replace_values(as.integer(SEVERIDAD), 9 ~ NA),
         depress_major = recode_values(CUADROS, "1" ~ 1, "9" ~ NA, default = 0),
         depress_other = recode_values(CUADROS, "2" ~ 1, "9" ~ NA, default = 0),
         depress_none = recode_values(CUADROS, "3" ~ 1, "9" ~ NA, default = 0),
  )


saveRDS(db, file = "./health.rds", compress = "xz")

db |>
  select(-c(CCAA, NORDEN, SEXO, EDAD, A1a, A2a_1, A2a_2, A2a_3, A4, A5,
            NIVEST, B8, B11, B12, B13a_2, B14a_2, C1, C2, C3a, C3b,
            E1, E2, O1, O2, Q1, Q2, S1, S2, S3, IMC, CMD1, SEVERIDAD, CUADROS,
            id, ESTRATO, NADULTOS, NMENORES, A12, INGRESOS, CLASE_PR, A11)) |>
write_xlsx(path = "./health.xlsx")


