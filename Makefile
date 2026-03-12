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


all: $(all-data-files) $(doc-files)


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

adult-raw-data-deps := \
	$(common-deps) \
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
