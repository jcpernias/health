SHELL := /bin/sh

proj-dir := .
raw-dir := $(proj-dir)/raw

hh-raw-data-files := $(addprefix $(raw-dir)/, $(addsuffix .rds, hh_common individuals))
adult-raw-data-files := $(raw-dir)/adults.rds

raw-data-files := $(hh-raw-data-files) $(adult-raw-data-files)
final-data-files := $(addprefix $(proj-dir)/health., rds xlsx)
all-data-files := $(raw-data-files) $(final-data-files)

html-files := $(proj-dir)/data.html
pdf-files := $(proj-dir)/data.pdf
doc-files := $(html-files) $(pdf-files)


.PHONY: all clean check-raw-data

all: check-raw-data $(all-data-files) $(doc-files)

check-raw-data: $(raw-dir)/check-data.R $(raw-dir)/checksums.csv $(proj-dir)/years.csv
	Rscript "$(raw-dir)/check-data.R" "$(raw-dir)"

# Validate even when generated data are already up to date, without forcing
# their reconstruction. Also guard the recipes that produce multiple files.
$(all-data-files) hh-raw-data-files.intermediate final-data-files.intermediate: | check-raw-data


$(hh-raw-data-files): hh-raw-data-files.intermediate
	@:

.INTERMEDIATE: hh-raw-data-files.intermediate

common-deps := $(proj-dir)/years.csv

hh-raw-data-deps := \
	$(common-deps) \
	$(raw-dir)/hogar_2014.txt.xz \
	$(raw-dir)/hogar_2020.txt.xz \
	$(raw-dir)/hogar_2023.txt.xz \
	$(raw-dir)/household-vars.csv \
	$(raw-dir)/household-vars-2014.csv \
	$(raw-dir)/household-vars-2017.csv \
	$(raw-dir)/household-vars-2020.csv \
	$(raw-dir)/household-vars-2023.csv


hh-raw-data-files.intermediate: $(raw-dir)/mkdata-hh.R $(hh-raw-data-deps)
	Rscript $<

adult-raw-data-deps := \
	$(common-deps) \
	$(raw-dir)/adultos_2014.txt.xz \
	$(raw-dir)/adultos_2020.txt.xz \
	$(raw-dir)/adultos_2023.txt.xz \
	$(raw-dir)/adult-vars.csv \
	$(raw-dir)/adult-vars-2014.csv \
	$(raw-dir)/adult-vars-2017.csv \
	$(raw-dir)/adult-vars-2020.csv \
	$(raw-dir)/adult-vars-2023.csv

$(raw-dir)/adults.rds: $(raw-dir)/mkdata-adults.R $(adult-raw-data-deps)
	Rscript $<


$(final-data-files): final-data-files.intermediate
	@:

.INTERMEDIATE: final-data-files.intermediate

final-data-files.intermediate: $(proj-dir)/health.R $(raw-data-files)
	Rscript $<

%.html: %.qmd
	quarto render $< --to html

%.pdf: %.qmd
	quarto render $< --to pdf


clean:
	-@rm $(all-data-files) $(doc-files)
