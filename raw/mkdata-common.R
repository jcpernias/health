library(dplyr)
library(purrr)
library(readr)
library(glue)


# Read path to raw data files.
# The file `raw-data-path.txt` should contain the path to the
# folder where the raw data files are.
raw_data_path <- readLines("./raw/raw-data-path.txt")

# Years
years <- c(2014, 2020, 2023)

# Variable types
# var_types <- read_csv("./raw/var-types.csv", col_types = "cci")

