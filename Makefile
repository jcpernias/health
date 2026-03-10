SHELL := /bin/sh

proj-dir := .
raw-dir := $(proj-dir)/raw

hh-raw-data-files := $(addprefix $(raw-dir)/, $(addsuffix .rds, hh_common individuals))

all: $(hh-raw-data-files)


$(hh-raw-data-files): hh-raw-data-files.intermediate
	@:

.INTERMEDIATE: hh-raw-data-files.intermediate

common-deps := \
	$(raw-dir)/mkdata-common.R \
	$(raw-dir)/raw-data-path.txt

hh-raw-data-deps := \
	$(common-deps) \
	$(raw-dir)/household-vars.csv \
	$(raw-dir)/household-vars-2014.csv \
	$(raw-dir)/household-vars-2017.csv \
	$(raw-dir)/household-vars-2020.csv \
	$(raw-dir)/household-vars-2023.csv

hh-raw-data-files.intermediate: $(raw-dir)/mkdata-hh.R $(hh-raw-data-deps)
	Rscript $<

clean:
	-@rm $(hh-raw-data-files)
