SHELL := /bin/sh

proj-dir := .
raw-dir := $(proj-dir)/raw

raw-data-files := $(addprefix $(raw-dir)/, $(addsuffix .rds, adults hh_common individuals))
final-data-files := $(addprefix $(proj-dir)/health., rds xlsx)
all-data-files := $(raw-data-files) $(final-data-files)

html-files := $(proj-dir)/data.html
pdf-files := $(proj-dir)/data.pdf
doc-files := $(html-files) $(pdf-files)


.PHONY: all build clean check-raw-data

# Finish validation before starting build; its prerequisites can run in parallel.
.NOTPARALLEL: all
all: check-raw-data build

build: $(all-data-files) $(doc-files)

# Recalculate selected checksums on every build, without caching them.
check-raw-data: $(raw-dir)/utils.R $(raw-dir)/check-data.R $(raw-dir)/checksums.csv $(proj-dir)/years.txt
	Rscript "$(raw-dir)/check-data.R" "$(raw-dir)"

# Rebuild documentation when the selected years change.
$(doc-files): $(proj-dir)/years.txt

# Guard direct targets and make -k too, without forcing reconstruction.
# Include documents and the recipes that produce multiple data files.
$(all-data-files) $(doc-files) raw-data-files.intermediate final-data-files.intermediate: | check-raw-data


$(raw-data-files): raw-data-files.intermediate
	@:

.INTERMEDIATE: raw-data-files.intermediate

raw-data-deps := \
	$(proj-dir)/years.txt \
	$(raw-dir)/utils.R \
	$(raw-dir)/household-vars.csv \
	$(raw-dir)/household-vars-2014.csv \
	$(raw-dir)/household-vars-2017.csv \
	$(raw-dir)/household-vars-2020.csv \
	$(raw-dir)/household-vars-2023.csv \
	$(raw-dir)/adult-vars.csv \
	$(raw-dir)/adult-vars-2014.csv \
	$(raw-dir)/adult-vars-2017.csv \
	$(raw-dir)/adult-vars-2020.csv \
	$(raw-dir)/adult-vars-2023.csv

raw-data-files.intermediate: $(raw-dir)/mkdata.R $(raw-data-deps)
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
