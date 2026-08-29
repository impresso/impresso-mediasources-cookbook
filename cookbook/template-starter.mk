# create a copy of all template-specific cookbook files

PROCESSING_ACRONYM ?= myprocessing

# Find all template files
TEMPLATE_FILES := $(wildcard cookbook/*_TEMPLATE.mk)
# Generate target filenames by substituting TEMPLATE with PROCESSING_ACRONYM
TARGET_FILES := $(TEMPLATE_FILES:_TEMPLATE.mk=_$(PROCESSING_ACRONYM).mk)

# PROCESSING_MAKEFILE: cookbook/processing_myprocessing.mk

PROCESSING_CLI_FILE := lib/cli_$(PROCESSING_ACRONYM).py

create-newprocessing-cookbook-starter: $(TARGET_FILES) $(PROCESSING_CLI_FILE) Makefile.$(PROCESSING_ACRONYM)

# Pattern rule to create target files from template files
cookbook/%_$(PROCESSING_ACRONYM).mk: cookbook/%_TEMPLATE.mk
	sed 's/TEMPLATE/$(PROCESSING_ACRONYM)/g' $< > $@

$(PROCESSING_CLI_FILE): lib/cli_TEMPLATE.py
	sed 's/TEMPLATE/$(PROCESSING_ACRONYM)/g' $< > $@

Makefile.$(PROCESSING_ACRONYM): Makefile
	sed 's/TEMPLATE/$(PROCESSING_ACRONYM)/g' $< > $@

.PHONY: create-newprocessing-cookbook-starter
