$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/aggregators_lingproc.mk)
###############################################################################
# LINGUISTIC PROCESSING WORD FREQUENCY AGGREGATORS
# Targets for computing and aggregating word frequency distributions from linguistic processing data
#
# This module provides parallel word frequency computation from S3-stored linguistic
# processing data, organized by newspaper and language. Supports resumable
# processing with S3 existence checks and local-first workflow with stampification.
# 
# The extraction process reads linguistic processing JSON files from S3, applies
# jq filters to compute word frequency distributions for specific languages, and stores 
# results in a component bucket with proper versioning and organization.
###############################################################################


# USER-VARIABLE: S3_BUCKET_LINGPROC_COMPONENT
# Component bucket for storing aggregated linguistic processing results
#
# Specifies the S3 bucket where token aggregation results are stored,
# separate from the main linguistic processing data bucket. This separation
# allows for better organization and access control of derived data products.
S3_BUCKET_LINGPROC_COMPONENT ?= 130-component-sandbox
  $(call log.debug, S3_BUCKET_LINGPROC_COMPONENT)


# VARIABLE: ALL_NEWSPAPERS
# List all available newspapers for parallel processing using newspaper list definitions
#
# Reads the canonical list of newspaper identifiers using make's file function
# and newspaper_list.mk definitions to determine which newspapers should be processed.
ALL_NEWSPAPERS := $(file < build.d/newspapers.txt)


# VARIABLE: S3_FREQS_BASE_PATH
# Base S3 path for storing word frequency files in component bucket
#
# Constructs the S3 path using the component bucket and run ID to ensure
# proper versioning and organization of word frequency distribution files. The path structure
# follows the pattern: s3://bucket/token-freq/run-id/language/newspaper_freqs.jsonl.bz2
S3_FREQS_BASE_PATH := s3://$(S3_BUCKET_LINGPROC_COMPONENT)/token-freq/$(RUN_ID_LINGPROC)
  $(call log.debug, S3_FREQS_BASE_PATH)


# VARIABLE: LOCAL_FREQS_BASE_PATH
# Local path for storing word frequency files (mirrors S3 structure)
#
# Defines the local build directory path that mirrors the S3 structure
# for temporary storage before upload and stampification. Files are processed
# locally first for reliability and then uploaded with verification.
LOCAL_FREQS_BASE_PATH := $(BUILD_DIR)/$(S3_BUCKET_LINGPROC_COMPONENT)/token-freq/$(RUN_ID_LINGPROC)
  $(call log.debug, LOCAL_FREQS_BASE_PATH)


# PATTERN-RULE: compute-frequencies-%-de
#: Compute German word frequency distribution for a specific newspaper
#
# Processes all linguistic processing files for a newspaper to compute German
# word frequency distributions using jq filters. The process includes S3 existence checking for
# resumability, local processing with logging, and upload with stampification.
# Skips processing if output already exists on S3 to enable parallel execution.
compute-frequencies-%-de:
	@mkdir -p $(LOCAL_FREQS_BASE_PATH)/de
	@set +e; \
	python3 -m impresso_cookbook.local_to_s3 --exit-2-if-exists --s3-file-exists $(S3_FREQS_BASE_PATH)/de/$*_de_freqs.jsonl.bz2 --wip --wip-max-age 2 --create-wip $(LOCAL_FREQS_BASE_PATH)/de/$*_de_freqs.jsonl.bz2 $(S3_FREQS_BASE_PATH)/de/$*_de_freqs.jsonl.bz2 $(LOCAL_FREQS_BASE_PATH)/de/$*_de_freqs.log.gz $(S3_FREQS_BASE_PATH)/de/$*_de_freqs.log.gz ; status=$$?; \
	set -e; \
	if [ $$status -eq 2 ]; then \
		echo "File already exists or WIP in progress, skipping processing for $*_de_freqs.jsonl.bz2"; \
	elif [ $$status -ne 0 ]; then \
		exit $$status; \
	else \
		LANGUAGE=de python cookbook/lib/s3_aggregator.py --jq-filter lib/compute_word_frequencies.jq \
		--s3-prefix s3://$(PATH_LINGPROC_BASE)/$* \
		-o $(LOCAL_FREQS_BASE_PATH)/de/$*_de_freqs.jsonl.bz2 \
		--log-file $(LOCAL_FREQS_BASE_PATH)/de/$*_de_freqs.log.gz && \
		python3 -m impresso_cookbook.local_to_s3 \
		--keep-timestamp-only \
		--set-timestamp \
		--ts-key __file__ \
		--remove-wip \
		$(LOCAL_FREQS_BASE_PATH)/de/$*_de_freqs.jsonl.bz2 $(S3_FREQS_BASE_PATH)/de/$*_de_freqs.jsonl.bz2 \
		$(LOCAL_FREQS_BASE_PATH)/de/$*_de_freqs.log.gz $(S3_FREQS_BASE_PATH)/de/$*_de_freqs.log.gz; \
	fi


# PATTERN-RULE: compute-frequencies-%-fr
#: Compute French word frequency distribution for a specific newspaper
#
# Processes all linguistic processing files for a newspaper to compute French
# word frequency distributions using jq filters. The process includes S3 existence checking for
# resumability, local processing with logging, and upload with stampification.
# Skips processing if output already exists on S3 to enable parallel execution.
compute-frequencies-%-fr:
	@mkdir -p $(LOCAL_FREQS_BASE_PATH)/fr
	@set +e; \
	python3 -m impresso_cookbook.local_to_s3 --exit-2-if-exists --s3-file-exists $(S3_FREQS_BASE_PATH)/fr/$*_fr_freqs.jsonl.bz2 --wip --wip-max-age 2 --create-wip $(LOCAL_FREQS_BASE_PATH)/fr/$*_fr_freqs.jsonl.bz2 $(S3_FREQS_BASE_PATH)/fr/$*_fr_freqs.jsonl.bz2 $(LOCAL_FREQS_BASE_PATH)/fr/$*_fr_freqs.log.gz $(S3_FREQS_BASE_PATH)/fr/$*_fr_freqs.log.gz ; status=$$?; \
	set -e; \
	if [ $$status -eq 2 ]; then \
		echo "File already exists or WIP in progress, skipping processing for $*_fr_freqs.jsonl.bz2"; \
	elif [ $$status -ne 0 ]; then \
		exit $$status; \
	else \
		LANGUAGE=fr python cookbook/lib/s3_aggregator.py --jq-filter lib/compute_word_frequencies.jq \
		--s3-prefix s3://$(PATH_LINGPROC_BASE)/$* \
		-o $(LOCAL_FREQS_BASE_PATH)/fr/$*_fr_freqs.jsonl.bz2 \
		--log-file $(LOCAL_FREQS_BASE_PATH)/fr/$*_fr_freqs.log.gz && \
		python3 -m impresso_cookbook.local_to_s3 \
		--keep-timestamp-only \
		--set-timestamp \
		--ts-key __file__ \
		--remove-wip \
		$(LOCAL_FREQS_BASE_PATH)/fr/$*_fr_freqs.jsonl.bz2 $(S3_FREQS_BASE_PATH)/fr/$*_fr_freqs.jsonl.bz2 \
		$(LOCAL_FREQS_BASE_PATH)/fr/$*_fr_freqs.log.gz $(S3_FREQS_BASE_PATH)/fr/$*_fr_freqs.log.gz; \
	fi


# PATTERN-RULE: compute-frequencies-%-en
#: Compute English word frequency distribution for a specific newspaper
#
# Processes all linguistic processing files for a newspaper to compute English
# word frequency distributions using jq filters. The process includes S3 existence checking for
# resumability, local processing with logging, and upload with stampification.
# Skips processing if output already exists on S3 to enable parallel execution.
compute-frequencies-%-en:
	@mkdir -p $(LOCAL_FREQS_BASE_PATH)/en
	@set +e; \
	python3 -m impresso_cookbook.local_to_s3 --exit-2-if-exists --s3-file-exists $(S3_FREQS_BASE_PATH)/en/$*_en_freqs.jsonl.bz2 --wip --wip-max-age 2 --create-wip $(LOCAL_FREQS_BASE_PATH)/en/$*_en_freqs.jsonl.bz2 $(S3_FREQS_BASE_PATH)/en/$*_en_freqs.jsonl.bz2 $(LOCAL_FREQS_BASE_PATH)/en/$*_en_freqs.log.gz $(S3_FREQS_BASE_PATH)/en/$*_en_freqs.log.gz ; status=$$?; \
	set -e; \
	if [ $$status -eq 2 ]; then \
		echo "File already exists or WIP in progress, skipping processing for $*_en_freqs.jsonl.bz2"; \
	elif [ $$status -ne 0 ]; then \
		exit $$status; \
	else \
		LANGUAGE=en python cookbook/lib/s3_aggregator.py --jq-filter lib/compute_word_frequencies.jq \
		--s3-prefix s3://$(PATH_LINGPROC_BASE)/$* \
		-o $(LOCAL_FREQS_BASE_PATH)/en/$*_en_freqs.jsonl.bz2 \
		--log-file $(LOCAL_FREQS_BASE_PATH)/en/$*_en_freqs.log.gz && \
		python3 -m impresso_cookbook.local_to_s3 \
		--keep-timestamp-only \
		--set-timestamp \
		--ts-key __file__ \
		--remove-wip \
		$(LOCAL_FREQS_BASE_PATH)/en/$*_en_freqs.jsonl.bz2 $(S3_FREQS_BASE_PATH)/en/$*_en_freqs.jsonl.bz2 \
		$(LOCAL_FREQS_BASE_PATH)/en/$*_en_freqs.log.gz $(S3_FREQS_BASE_PATH)/en/$*_en_freqs.log.gz; \
	fi


# Explicitly generate per-newspaper targets so newspaper ids containing provider
# prefixes, such as BNF/legaulois, are matched as full target names.
define compute_frequency_rule
compute-frequencies-$(1)-$(2):
	@mkdir -p $(dir $(LOCAL_FREQS_BASE_PATH)/$(2)/$(1)_$(2)_freqs.jsonl.bz2)
	@set +e; \
	python3 -m impresso_cookbook.local_to_s3 --exit-2-if-exists --s3-file-exists $(S3_FREQS_BASE_PATH)/$(2)/$(1)_$(2)_freqs.jsonl.bz2 --wip --wip-max-age 2 --create-wip $(LOCAL_FREQS_BASE_PATH)/$(2)/$(1)_$(2)_freqs.jsonl.bz2 $(S3_FREQS_BASE_PATH)/$(2)/$(1)_$(2)_freqs.jsonl.bz2 $(LOCAL_FREQS_BASE_PATH)/$(2)/$(1)_$(2)_freqs.log.gz $(S3_FREQS_BASE_PATH)/$(2)/$(1)_$(2)_freqs.log.gz ; status=$$$$?; \
	set -e; \
	if [ $$$$status -eq 2 ]; then \
		echo "File already exists or WIP in progress, skipping processing for $(1)_$(2)_freqs.jsonl.bz2"; \
	elif [ $$$$status -ne 0 ]; then \
		exit $$$$status; \
	else \
		LANGUAGE=$(2) python cookbook/lib/s3_aggregator.py --jq-filter lib/compute_word_frequencies.jq \
		--s3-prefix s3://$(PATH_LINGPROC_BASE)/$(1) \
		-o $(LOCAL_FREQS_BASE_PATH)/$(2)/$(1)_$(2)_freqs.jsonl.bz2 \
		--log-file $(LOCAL_FREQS_BASE_PATH)/$(2)/$(1)_$(2)_freqs.log.gz && \
		python3 -m impresso_cookbook.local_to_s3 \
		--keep-timestamp-only \
		--set-timestamp \
		--ts-key __file__ \
		--remove-wip \
		$(LOCAL_FREQS_BASE_PATH)/$(2)/$(1)_$(2)_freqs.jsonl.bz2 $(S3_FREQS_BASE_PATH)/$(2)/$(1)_$(2)_freqs.jsonl.bz2 \
		$(LOCAL_FREQS_BASE_PATH)/$(2)/$(1)_$(2)_freqs.log.gz $(S3_FREQS_BASE_PATH)/$(2)/$(1)_$(2)_freqs.log.gz; \
	fi
endef

$(foreach newspaper,$(ALL_NEWSPAPERS),$(foreach language,de fr en,$(eval $(call compute_frequency_rule,$(newspaper),$(language)))))


# PATTERN-RULE: aggregate-frequencies-%
#: Combine all newspaper frequency distributions for a specific language into corpus distribution
#
# Aggregates individual newspaper frequency distributions for a language into a single
# consolidated frequency distribution for corpus-wide analysis. Reads from S3,
# filters by language-specific filename patterns, and merges frequency counts
# with comprehensive logging for data provenance tracking.
aggregate-frequencies-%:
	@mkdir -p $(LOCAL_FREQS_BASE_PATH)
	python cookbook/lib/s3_aggregator.py --s3-prefix $(S3_FREQS_BASE_PATH) \
	--filter filename=*_$*_freqs.jsonl.bz2 \
	--jq-filter lib/merge_word_frequencies.jq \
	--keys content \
	-o $(LOCAL_FREQS_BASE_PATH)/ALL_$*_freqs.jsonl.bz2 \
	--log-file $(LOCAL_FREQS_BASE_PATH)/ALL_$*_freqs.log.gz
	python3 -m impresso_cookbook.local_to_s3 \
	--keep-timestamp-only \
	--set-timestamp \
	--ts-key __file__ \
	$(LOCAL_FREQS_BASE_PATH)/ALL_$*_freqs.jsonl.bz2 $(S3_FREQS_BASE_PATH)/ALL_$*_freqs.jsonl.bz2 \
	$(LOCAL_FREQS_BASE_PATH)/ALL_$*_freqs.log.gz $(S3_FREQS_BASE_PATH)/ALL_$*_freqs.log.gz


# TARGET: compute-frequencies-de
#: Compute German word frequencies for all newspapers in parallel
#
# Processes all newspapers concurrently using make's parallel job execution.
# Each newspaper frequency computation runs independently, allowing for efficient resource
# utilization. Use with -j flag to control parallelism: make compute-frequencies-de -j4
compute-frequencies-de: $(foreach newspaper,$(ALL_NEWSPAPERS),compute-frequencies-$(newspaper)-de)


# TARGET: compute-frequencies-fr
#: Compute French word frequencies for all newspapers in parallel
#
# Processes all newspapers concurrently using make's parallel job execution.
# Each newspaper frequency computation runs independently, allowing for efficient resource
# utilization. Use with -j flag to control parallelism: make compute-frequencies-fr -j4
compute-frequencies-fr: $(foreach newspaper,$(ALL_NEWSPAPERS),compute-frequencies-$(newspaper)-fr)


# TARGET: compute-frequencies-en
#: Compute English word frequencies for all newspapers in parallel
#
# Processes all newspapers concurrently using make's parallel job execution.
# Each newspaper frequency computation runs independently, allowing for efficient resource
# utilization. Use with -j flag to control parallelism: make compute-frequencies-en -j4
compute-frequencies-en: $(foreach newspaper,$(ALL_NEWSPAPERS),compute-frequencies-$(newspaper)-en)


# TARGET: compute-all-frequencies
#: Compute word frequencies for all newspapers and all supported languages
#
# Comprehensive frequency computation across all supported languages and newspapers.
# Runs sequentially by language but newspapers within each language run in parallel.
# This is the main entry point for complete corpus frequency distribution workflows.
compute-all-frequencies: compute-frequencies-de compute-frequencies-fr compute-frequencies-en


# TARGET: list-newspapers
#: Display all available newspapers for frequency computation processing
#
# Shows the complete list of newspaper identifiers that will be processed for
# word frequency computation. Useful for verification and debugging of newspaper coverage
# before starting large-scale frequency computation operations.
list-newspapers: newspaper-list-target
	@echo "Available newspapers: $(ALL_NEWSPAPERS)"


# TARGET: compute-frequencies
#: Compute German word frequencies for all newspapers (backward compatibility)
#
# Default target that computes German word frequencies for all newspapers.
# Maintains compatibility with existing workflows that expect German
# as the default language for frequency computation operations.
compute-frequencies: compute-frequencies-de


.PHONY: compute-frequencies-de compute-frequencies-fr compute-frequencies-en compute-all-frequencies
.PHONY: aggregate-frequencies-de aggregate-frequencies-fr aggregate-frequencies-en
.PHONY: list-newspapers compute-frequencies

help-aggregation::
	@echo "LINGPROC FREQUENCY AGGREGATION:"
	@echo "  compute-frequencies       # Compute German word frequencies for all newspapers"
	@echo "  compute-frequencies-de    # Compute German word frequencies for all newspapers"
	@echo "  compute-frequencies-fr    # Compute French word frequencies for all newspapers"
	@echo "  compute-frequencies-en    # Compute English word frequencies for all newspapers"
	@echo "  compute-all-frequencies   # Compute all supported language frequencies"
	@echo "  aggregate-frequencies-de  # Aggregate German newspaper frequencies"
	@echo "  aggregate-frequencies-fr  # Aggregate French newspaper frequencies"
	@echo "  aggregate-frequencies-en  # Aggregate English newspaper frequencies"
	@echo "  list-newspapers           # Show newspapers selected for frequency computation"



$(call log.debug, COOKBOOK END INCLUDE: cookbook/aggregators_lingproc.mk)
