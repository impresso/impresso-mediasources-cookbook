$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sampling_rebuilt.mk)
###############################################################################
# SAMPLING TARGETS FOR REBUILT INPUT
#
# This file only wires generic cookbook tools to path conventions.
# Concrete jq filters and custom sampling logic belong in ./lib.
###############################################################################

# USER-VARIABLE: SAMPLE_SOURCE_PREFIX
# S3 prefix used as source input for sampling.
SAMPLE_SOURCE_PREFIX ?= $(S3_PATH_REBUILT)
  $(call log.debug, SAMPLE_SOURCE_PREFIX)

# USER-VARIABLE: SAMPLE_OUTPUT_BUCKET
# S3 bucket where sample outputs are written.
SAMPLE_OUTPUT_BUCKET ?= 140-processed-data-sandbox
  $(call log.debug, SAMPLE_OUTPUT_BUCKET)

# USER-VARIABLE: SAMPLE_OUTPUT_PREFIX
# S3 output prefix for sample outputs.
SAMPLE_OUTPUT_PREFIX ?= s3://$(SAMPLE_OUTPUT_BUCKET)/sampling/rebuilt/$(NEWSPAPER)
  $(call log.debug, SAMPLE_OUTPUT_PREFIX)

# USER-VARIABLE: SAMPLE_LABEL
# Label for the current sampling recipe.
SAMPLE_LABEL ?= random
  $(call log.debug, SAMPLE_LABEL)

# USER-VARIABLE: SAMPLE_TRANSFORM_FILE
# Default source-level extraction jq script.
SAMPLE_TRANSFORM_FILE ?= lib/sampling_rebuilt_base.jq
  $(call log.debug, SAMPLE_TRANSFORM_FILE)

# USER-VARIABLE: SAMPLE_FILTER_FILE
# Optional additional jq filter script.
SAMPLE_FILTER_FILE ?=
  $(call log.debug, SAMPLE_FILTER_FILE)

# USER-VARIABLE: SAMPLE_ID_FIELD
# Field name containing content item id.
SAMPLE_ID_FIELD ?= id
  $(call log.debug, SAMPLE_ID_FIELD)

# Local outputs
SAMPLE_LOCAL_DIR := $(BUILD_DIR)/sampling/rebuilt/$(NEWSPAPER)
SAMPLE_IDS_FILE := $(SAMPLE_LOCAL_DIR)/$(SAMPLE_LABEL).ids.jsonl.bz2
SAMPLE_COMPILED_FILE := $(SAMPLE_LOCAL_DIR)/$(SAMPLE_LABEL).compiled.jsonl.bz2

# S3 outputs
SAMPLE_IDS_S3 := $(SAMPLE_OUTPUT_PREFIX)/$(SAMPLE_LABEL).ids.jsonl.bz2
SAMPLE_COMPILED_S3 := $(SAMPLE_OUTPUT_PREFIX)/$(SAMPLE_LABEL).compiled.jsonl.bz2

# DOUBLE-COLON-TARGET: sample-target
sample-target:: sampling-rebuilt

#: Generate sampled IDs from rebuilt input
sampling-rebuilt-ids: $(SAMPLE_IDS_FILE)

.PHONY: sampling-rebuilt-ids

#: Compile sampled IDs into full records
sampling-rebuilt-compile: $(SAMPLE_COMPILED_FILE)

.PHONY: sampling-rebuilt-compile

#: Run rebuilt sampling pipeline (IDs + compiled records)
sampling-rebuilt: sampling-rebuilt-ids sampling-rebuilt-compile

.PHONY: sampling-rebuilt

help-sampling::
	@echo ""
	@echo "REBUILT SAMPLING:"
	@echo "  sampling-rebuilt         # Generate ID sample and compiled sample from rebuilt input"
	@echo "  sampling-rebuilt-ids     # Generate sampled IDs only"
	@echo "  sampling-rebuilt-compile # Compile sampled IDs into full records"


$(SAMPLE_IDS_FILE): | $(BUILD_DIR)
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	python3 cookbook/lib/s3_sampler.py \
	  --s3-prefix $(SAMPLE_SOURCE_PREFIX) \
	  --output $@ \
	  --sampling-rate $(SAMPLE_RATE) \
	  --random-seed $(SAMPLE_RANDOM_SEED) \
	  --record-id-field $(SAMPLE_ID_FIELD) \
	  --transform-file $(SAMPLE_TRANSFORM_FILE) \
	  $(if $(strip $(SAMPLE_FILTER_FILE)),--filter-file $(SAMPLE_FILTER_FILE),) \
	  --log-level $(SAMPLE_LOG_LEVEL) \
	  --log-file $@.log.gz \
	&& \
	python3 -m impresso_cookbook.local_to_s3 \
	  $@ $(SAMPLE_IDS_S3) \
	  $@.log.gz $(SAMPLE_IDS_S3).log.gz


$(SAMPLE_COMPILED_FILE): $(SAMPLE_IDS_FILE)
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	python3 cookbook/lib/s3_compiler.py \
	  --input-file $< \
	  --s3-prefix $(SAMPLE_SOURCE_PREFIX) \
	  --output $@ \
	  --id-field $(SAMPLE_ID_FIELD) \
	  --log-level $(SAMPLE_LOG_LEVEL) \
	  --log-file $@.log.gz \
	&& \
	python3 -m impresso_cookbook.local_to_s3 \
	  $@ $(SAMPLE_COMPILED_S3) \
	  $@.log.gz $(SAMPLE_COMPILED_S3).log.gz


$(call log.debug, COOKBOOK END INCLUDE: cookbook/sampling_rebuilt.mk)
