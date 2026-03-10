SHELL := /bin/sh

proj-dir := .
raw-dir := $(proj-dir)/raw

hh-raw-data-files := $(addprefix $(raw-dir)/, $(addsuffix .rds, hh_common individuals))

all: $(hh-raw-data-files)


$(hh-raw-data-files): hh-raw-data-files.intermediate
	@:

.INTERMEDIATE: hh-raw-data-files.intermediate

hh-raw-data-deps := \
	$(raw-dir)/mkdata-common.R \
	$(raw-dir)/household-vars.csv \
	$(raw-dir)/raw-data-path.txt

hh-raw-data-files.intermediate: $(raw-dir)/mkdata-hh.R $(hh-raw-data-deps)
	Rscript $<

clean:
	-@rm $(hh-raw-data-files)
