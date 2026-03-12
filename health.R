library(tidyverse)
library(writexl)

dummy <- function(x, values, na = NULL) {
  na_values <- NA
  if (!is.null(na)) {
    na_values <- c(na, NA)
  }
  recode_values(x, values ~ 1, na_values ~ NA, default = 0)
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
  mutate(
    age = EDAD,
    woman   = dummy(SEXO, "2"),
    partner = dummy(A4, c("1", "2"), na = c("8", "9")),
    native  = dummy(A2a_1, "1"),
    nadults   = NADULTOS,
    nchildren = NMENORES,
    hh_size   = nadults + nchildren,
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
    urb_high = dummy(ESTRATO, c("0", "1", "2", "3")),
    urb_med  = dummy(ESTRATO, c("4", "5")),
    urb_low  = dummy(ESTRATO, "6"),
    ed_none  = dummy(NIVEST, c("02", "03"), na = "99"),
    ed_prim  = dummy(NIVEST, "04", na = "99"),
    ed_sec   = dummy(NIVEST, c("05", "06", "07", "08"), na = "99"),
    ed_sup   = dummy(NIVEST, "09", na = "99"),
    a_working  = dummy(A11, "1"),
    a_unempl   = dummy(A11, "2"),
    a_retired  = dummy(A11, "3"),
    a_student  = dummy(A11, "4"),
    a_disabled = dummy(A11, "5"),
    a_house    = dummy(A11, "6"),
    a_other    = dummy(A11, "7"),
    b_public   = dummy(B8, "01", na = c("98", "99")),
    b_temp     = dummy(B8, "03", na = c("98", "99")),
    b_perm     = dummy(B8, c("01", "02"), na = c("98", "99")),
    b_employer = dummy(B8, "05", na = c("98", "99")),
    b_self     = dummy(B8, "06", na = c("98", "99")),
    b_other    = dummy(B8, c("04", "07", "08", "09"), na = c("98", "99")),
    b_fulltime = dummy(B11, "1", na = c("8", "9")),
    b_parttime = dummy(B11, "1", na = c("8", "9")),
    b_shift = dummy(B12, c("06", "07", "08"), na = c("98", "99")),
    c_health_status = as.integer(C1),
    c_chronic = dummy(C2, "1", na = c("8", "9")),
    c_severe_limit   = dummy(C3a, "1", na = c("8", "9")),
    c_moderate_limit = dummy(C3a, "2", na = c("8", "9")),
    c_no_limit       = dummy(C3a, "3", na = c("8", "9")),
    c_physical_limit = dummy(C3b, "1", na = c("8", "9")),
    c_mental_limit   = dummy(C3b, "2", na = c("8", "9")),
    c_both_limit     = dummy(C3b, "3", na = c("8", "9")),
    e_absence = dummy(E1, "1", na = c("8", "9")),
    e_absence_days = replace_values(E2, NA ~ 0),
    o_sedentary_work =
      dummy(O1, "1", na = c("5", "8", "9")) * replace_values(a_working, 0 ~ NA),
    o_sedentary_leisure = dummy(O2, "1", na = c("8", "9")),
    q_smoker = dummy(Q1, "1",  na = c("8", "9")),
    q_cigs = replace_values(Q2, NA ~ 0, 98:99 ~ NA),
    bmi_low  = dummy(IMC, "1", na = "9"),
    bmi_med  = dummy(IMC, c("2", "3") , na = "9"),
    bmi_high = dummy(IMC, "4", na = "9"),
    alcohol = replace_values(CMD1, 9.99 ~ NA),
    depress_severity = replace_values(as.integer(SEVERIDAD), 9 ~ NA),
    depress_major = dummy(CUADROS, "1", na = "9"),
    depress_other = dummy(CUADROS, "2", na = "9"),
    depress_none  = dummy(CUADROS, "3", na = "9"),
  )


saveRDS(db, file = "./health.rds", compress = "xz")

db |>
  select(-c(CCAA, NORDEN, SEXO, EDAD, A1a, A2a_1, A2a_2, A2a_3, A4, A5,
            NIVEST, B8, B11, B12, B13a_2, B14a_2, C1, C2, C3a, C3b,
            E1, E2, O1, O2, Q1, Q2, S1, S2, S3, IMC, CMD1, SEVERIDAD, CUADROS,
            id, ESTRATO, NADULTOS, NMENORES, A12, INGRESOS, CLASE_PR, A11)) |>
write_xlsx(path = "./health.xlsx")


