$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sampling_langident.mk)
###############################################################################
# SAMPLING TARGETS FOR LANGIDENT AGGREGATED INPUT
#
# Step 1: collect language-specific IDs from aggregated langident data
# Step 2: compile full records from content source by those IDs
###############################################################################

# USER-VARIABLE: LANGIDENT_AGGREGATED_S3
# Aggregated langident input containing at least id, lg, len, and ocrqa and provider.
LANGIDENT_AGGREGATED_S3 ?= s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2__AGGREGATED.jsonl.gz
  $(call log.debug, LANGIDENT_AGGREGATED_S3)

# USER-VARIABLE: LANGIDENT_SAMPLE_LANGUAGES
# Languages to process independently.
LANGIDENT_SAMPLE_LANGUAGES ?= de fr en lb
  $(call log.debug, LANGIDENT_SAMPLE_LANGUAGES)

# USER-VARIABLE: LANGIDENT_MIN_OCRQA
# Keep records with ocrqa > LANGIDENT_MIN_OCRQA.
LANGIDENT_MIN_OCRQA ?= 0.9
  $(call log.debug, LANGIDENT_MIN_OCRQA)

# USER-VARIABLE: LANGIDENT_MIN_OCRQA_de / _fr / _en / _lb
# Per-language ocrqa threshold overrides. Fall back to LANGIDENT_MIN_OCRQA if not set.
LANGIDENT_MIN_OCRQA_de ?= $(LANGIDENT_MIN_OCRQA)
LANGIDENT_MIN_OCRQA_fr ?= $(LANGIDENT_MIN_OCRQA)
LANGIDENT_MIN_OCRQA_en ?= $(LANGIDENT_MIN_OCRQA)
LANGIDENT_MIN_OCRQA_lb ?= $(LANGIDENT_MIN_OCRQA)
  $(call log.debug, LANGIDENT_MIN_OCRQA_de)
  $(call log.debug, LANGIDENT_MIN_OCRQA_fr)
  $(call log.debug, LANGIDENT_MIN_OCRQA_en)
  $(call log.debug, LANGIDENT_MIN_OCRQA_lb)

# USER-VARIABLE: LANGIDENT_MIN_CHARS
# Keep records with len >= LANGIDENT_MIN_CHARS.
LANGIDENT_MIN_CHARS ?= 200
  $(call log.debug, LANGIDENT_MIN_CHARS)

# USER-VARIABLE: LANGIDENT_MIN_CHARS_de / _fr / _en / _lb
# Per-language minimum character count overrides. Fall back to LANGIDENT_MIN_CHARS if not set.
LANGIDENT_MIN_CHARS_de ?= $(LANGIDENT_MIN_CHARS)
LANGIDENT_MIN_CHARS_fr ?= $(LANGIDENT_MIN_CHARS)
LANGIDENT_MIN_CHARS_en ?= $(LANGIDENT_MIN_CHARS)
LANGIDENT_MIN_CHARS_lb ?= $(LANGIDENT_MIN_CHARS)
  $(call log.debug, LANGIDENT_MIN_CHARS_de)
  $(call log.debug, LANGIDENT_MIN_CHARS_fr)
  $(call log.debug, LANGIDENT_MIN_CHARS_en)
  $(call log.debug, LANGIDENT_MIN_CHARS_lb)

# USER-VARIABLE: LANGIDENT_MAX_PER_NEWSPAPER_YEAR
# Maximum selected records per newspaper-year group.
LANGIDENT_MAX_PER_NEWSPAPER_YEAR ?= 500
  $(call log.debug, LANGIDENT_MAX_PER_NEWSPAPER_YEAR)

# USER-VARIABLE: LANGIDENT_FULLTEXT_PREFIX
# Source prefix used by s3_compiler to fetch full records.
LANGIDENT_FULLTEXT_PREFIX ?= s3://122-rebuilt-final
  $(call log.debug, LANGIDENT_FULLTEXT_PREFIX)

# USER-VARIABLE: LANGIDENT_OUTPUT_BUCKET
# Target bucket for language-specific outputs.
LANGIDENT_OUTPUT_BUCKET ?= 140-processed-data-sandbox
  $(call log.debug, LANGIDENT_OUTPUT_BUCKET)

# USER-VARIABLE: PROCESS_LABEL_SAMPLING
# Label for sampling outputs.
PROCESS_LABEL_SAMPLING ?= sampling
  $(call log.debug, PROCESS_LABEL_SAMPLING)

# USER-VARIABLE: TASK_SAMPLING
# Sampling task identifier.
TASK_SAMPLING ?= langident
  $(call log.debug, TASK_SAMPLING)

# USER-VARIABLE: MODEL_ID_SAMPLING
# Sampling model/source identifier.
MODEL_ID_SAMPLING ?= lid-ensemble_multilingual_v2-0-2
  $(call log.debug, MODEL_ID_SAMPLING)

# USER-VARIABLE: SAMPLING_PARAMS_INFIX
# Optional infix encoding sampling hyperparameters (e.g. ocrqa thresholds, min chars, max samples).
# When set, it is inserted between MODEL_ID_SAMPLING and RUN_VERSION_SAMPLING in RUN_ID_SAMPLING.
# If not set, it is computed from LANGIDENT_MIN_OCRQA, LANGIDENT_MIN_CHARS, and LANGIDENT_MAX_PER_NEWSPAPER_YEAR.
# Example: ocrqa90-minlen200-max500
SAMPLING_PARAMS_INFIX ?= ocrqa$(shell printf "%.0f" "$$(echo '$(LANGIDENT_MIN_OCRQA) * 100' | bc)")-minlen$(LANGIDENT_MIN_CHARS)-max$(LANGIDENT_MAX_PER_NEWSPAPER_YEAR)
  $(call log.debug, SAMPLING_PARAMS_INFIX)

# USER-VARIABLE: RUN_VERSION_SAMPLING
# Sampling run version identifier.
RUN_VERSION_SAMPLING ?= v1-0-0
  $(call log.debug, RUN_VERSION_SAMPLING)

# VARIABLE: _SAMPLING_PARAMS_INFIX_SEP
# Internal: separator before infix, only when infix is non-empty.
_SAMPLING_PARAMS_INFIX_SEP := $(if $(SAMPLING_PARAMS_INFIX),-$(SAMPLING_PARAMS_INFIX),)

# USER-VARIABLE: RUN_ID_SAMPLING
# Unique run identifier used in output paths.
RUN_ID_SAMPLING ?= $(PROCESS_LABEL_SAMPLING)-$(TASK_SAMPLING)-$(MODEL_ID_SAMPLING)$(_SAMPLING_PARAMS_INFIX_SEP)_$(RUN_VERSION_SAMPLING)
  $(call log.debug, RUN_ID_SAMPLING)

# USER-VARIABLE: LANGIDENT_OUTPUT_KEY_PREFIX
# Key prefix under the output bucket.
LANGIDENT_OUTPUT_KEY_PREFIX ?= sampling/langident/$(RUN_ID_SAMPLING)
  $(call log.debug, LANGIDENT_OUTPUT_KEY_PREFIX)

# USER-VARIABLE: LANGIDENT_OUTPUT_PREFIX
# Target prefix for language-specific outputs.
LANGIDENT_OUTPUT_PREFIX ?= s3://$(LANGIDENT_OUTPUT_BUCKET)/$(LANGIDENT_OUTPUT_KEY_PREFIX)
  $(call log.debug, LANGIDENT_OUTPUT_PREFIX)

LANGIDENT_SAMPLE_DIR := $(BUILD_DIR)/$(LANGIDENT_OUTPUT_BUCKET)/$(LANGIDENT_OUTPUT_KEY_PREFIX)
LANGIDENT_IDS_FILES := $(foreach L,$(LANGIDENT_SAMPLE_LANGUAGES),$(LANGIDENT_SAMPLE_DIR)/$(L).ids.jsonl.gz)
LANGIDENT_COMPILED_FILES := $(foreach L,$(LANGIDENT_SAMPLE_LANGUAGES),$(LANGIDENT_SAMPLE_DIR)/$(L).compiled.jsonl.bz2)

# USER-VARIABLE: LANGIDENT_MAX_ITEMS
# Stop ID collection after keeping this many items (0 = no limit; for testing).
LANGIDENT_MAX_ITEMS ?= 0
  $(call log.debug, LANGIDENT_MAX_ITEMS)

# USER-VARIABLE: LANGIDENT_UPLOAD_ENABLED
# If set to 0, keep outputs locally and skip upload to S3.
LANGIDENT_UPLOAD_ENABLED ?= 1
  $(call log.debug, LANGIDENT_UPLOAD_ENABLED)

# USER-VARIABLE: LANGIDENT_CHECK_OUTPUT_BUCKET
# If set to 1, verify output bucket accessibility before upload.
LANGIDENT_CHECK_OUTPUT_BUCKET ?= 1
  $(call log.debug, LANGIDENT_CHECK_OUTPUT_BUCKET)

# Convert local mirrored output path to S3 path
# $(1) local file path under LANGIDENT_SAMPLE_DIR
define LocalLangidentToS3
$(1:$(LANGIDENT_SAMPLE_DIR)/%=$(LANGIDENT_OUTPUT_PREFIX)/%)
endef

#: Create ID samples for all configured languages
sampling-langident-ids: $(LANGIDENT_IDS_FILES)

.PHONY: sampling-langident-ids

#: Compile full records for all configured languages
sampling-langident-compile: $(LANGIDENT_COMPILED_FILES)

.PHONY: sampling-langident-compile

#: Run langident two-step pipeline for all configured languages
sampling-langident: sampling-langident-ids sampling-langident-compile

.PHONY: sampling-langident

help-sampling::
	@echo ""
	@echo "LANGIDENT SAMPLING:"
	@echo "  sampling-langident         # IDs then fulltext compilation for de/fr/en/lb"
	@echo "  sampling-langident-ids     # Collect IDs from langident aggregate"
	@echo "  sampling-langident-compile # Compile full records from collected IDs"
	@echo "  sampling-langident-de      # Run IDs+compile for de"
	@echo "  sampling-langident-fr      # Run IDs+compile for fr"
	@echo "  sampling-langident-en      # Run IDs+compile for en"
	@echo "  sampling-langident-lb      # Run IDs+compile for lb"


# Per-language entry points
sampling-langident-de: $(LANGIDENT_SAMPLE_DIR)/de.ids.jsonl.gz $(LANGIDENT_SAMPLE_DIR)/de.compiled.jsonl.bz2

.PHONY: sampling-langident-de

sampling-langident-fr: $(LANGIDENT_SAMPLE_DIR)/fr.ids.jsonl.gz $(LANGIDENT_SAMPLE_DIR)/fr.compiled.jsonl.bz2

.PHONY: sampling-langident-fr

sampling-langident-en: $(LANGIDENT_SAMPLE_DIR)/en.ids.jsonl.gz $(LANGIDENT_SAMPLE_DIR)/en.compiled.jsonl.bz2

.PHONY: sampling-langident-en

sampling-langident-lb: $(LANGIDENT_SAMPLE_DIR)/lb.ids.jsonl.gz $(LANGIDENT_SAMPLE_DIR)/lb.compiled.jsonl.bz2

.PHONY: sampling-langident-lb

# Keep local targets when upload step fails.
.PRECIOUS: $(LANGIDENT_SAMPLE_DIR)/%.ids.jsonl.gz
.PRECIOUS: $(LANGIDENT_SAMPLE_DIR)/%.compiled.jsonl.bz2


# Check S3 output bucket accessibility with current credentials.
check-langident-output-bucket:
	@if [ "$(LANGIDENT_UPLOAD_ENABLED)" = "1" ] && [ "$(LANGIDENT_CHECK_OUTPUT_BUCKET)" = "1" ]; then \
	  command -v aws >/dev/null 2>&1 || { \
	    echo "ERROR: aws CLI not found. Install aws CLI or set LANGIDENT_CHECK_OUTPUT_BUCKET=0"; \
	    exit 2; \
	  }; \
	  AWS_ACCESS_KEY_ID="$(SE_ACCESS_KEY)" \
	  AWS_SECRET_ACCESS_KEY="$(SE_SECRET_KEY)" \
	  AWS_DEFAULT_REGION="us-east-1" \
	  aws s3api head-bucket \
	    --bucket "$(LANGIDENT_OUTPUT_BUCKET)" \
	    --endpoint-url "$(SE_HOST_URL)" \
	    >/dev/null 2>&1 || { \
	      echo "ERROR: output bucket is not accessible: $(LANGIDENT_OUTPUT_BUCKET)"; \
	      echo "Tip: override LANGIDENT_OUTPUT_BUCKET to an existing bucket or set LANGIDENT_UPLOAD_ENABLED=0"; \
	      exit 2; \
	    }; \
	  echo "Output bucket is accessible: $(LANGIDENT_OUTPUT_BUCKET)"; \
	fi

.PHONY: check-langident-output-bucket


$(LANGIDENT_SAMPLE_DIR)/%.ids.jsonl.gz: | $(BUILD_DIR) check-langident-output-bucket
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	python3 lib/sampling_langident_ids.py \
	  --input-file $(LANGIDENT_AGGREGATED_S3) \
	  --output-file $@ \
	  --language $* \
	  --min-ocrqa $(LANGIDENT_MIN_OCRQA_$*) \
	  --min-chars $(LANGIDENT_MIN_CHARS_$*) \
	  --max-per-newspaper-year $(LANGIDENT_MAX_PER_NEWSPAPER_YEAR) \
	  $(if $(filter-out 0,$(LANGIDENT_MAX_ITEMS)),--max-items $(LANGIDENT_MAX_ITEMS),) \
	  --log-level $(SAMPLE_LOG_LEVEL) \
	  --log-file $@.log.gz \
	&& \
	if [ "$(LANGIDENT_UPLOAD_ENABLED)" = "1" ]; then \
	  python3 -m impresso_cookbook.local_to_s3 \
	    $@ $(call LocalLangidentToS3,$@) \
	    $@.log.gz $(call LocalLangidentToS3,$@).log.gz ; \
	else \
	  echo "LANGIDENT_UPLOAD_ENABLED=0, keeping local outputs only: $@" ; \
	fi


$(LANGIDENT_SAMPLE_DIR)/%.compiled.jsonl.bz2: $(LANGIDENT_SAMPLE_DIR)/%.ids.jsonl.gz | check-langident-output-bucket
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	python3 cookbook/lib/s3_compiler.py \
	  --input-file $< \
	  --s3-prefix $(LANGIDENT_FULLTEXT_PREFIX) \
	  --output $@ \
	  --id-field id \
	  --include-from-input provider lg len ocrqa newspaper year \
	  --transform-expr '{id: .id, ft: .ft, consolidated_ocrqa: .consolidated_ocrqa, lb: .lb}' \
	  --log-level $(SAMPLE_LOG_LEVEL) \
	  --log-file $@.log.gz \
	&& \
	if [ "$(LANGIDENT_UPLOAD_ENABLED)" = "1" ]; then \
	  python3 -m impresso_cookbook.local_to_s3 \
	    $@ $(call LocalLangidentToS3,$@) \
	    $@.log.gz $(call LocalLangidentToS3,$@).log.gz ; \
	else \
	  echo "LANGIDENT_UPLOAD_ENABLED=0, keeping local outputs only: $@" ; \
	fi


$(call log.debug, COOKBOOK END INCLUDE: cookbook/sampling_langident.mk)
