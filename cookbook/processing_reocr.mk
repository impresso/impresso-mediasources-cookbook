$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_reocr.mk)
###############################################################################
# reocr TARGETS
###############################################################################

sync-output :: sync-reocr sync-reocr-collected
sync-input :: sync-reocr-input
processing-target :: reocr-target

REOCR_INPUT_FIND_ROOTS := $(if $(REOCR_INPUT_YEAR_DIRS),$(foreach dir,$(REOCR_INPUT_YEAR_DIRS),$(LOCAL_PATH_REOCR_INPUT)/$(dir)),$(LOCAL_PATH_REOCR_INPUT))
REOCR_INPUT_FIND_DEPTH := $(if $(REOCR_INPUT_YEAR_DIRS),-maxdepth 1,-mindepth 2 -maxdepth 2)

LOCAL_REOCR_INPUT_STAMP_FILES := \
    $(shell find $(REOCR_INPUT_FIND_ROOTS) $(REOCR_INPUT_FIND_DEPTH) -type f -name '*.jsonl.bz2' -print 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_REOCR_INPUT_STAMP_FILES)

define LocalReocrInputToDoneFile
$(patsubst $(LOCAL_PATH_REOCR_INPUT)/%.jsonl.bz2,$(LOCAL_PATH_reocr_STAMPS)/%.done,$(1))
endef

LOCAL_reocr_DONE_FILES := \
    $(call LocalReocrInputToDoneFile,$(LOCAL_REOCR_INPUT_STAMP_FILES))
  $(call log.debug, LOCAL_reocr_DONE_FILES)

LOCAL_REOCR_COLLECT_YEAR_DIRS := \
    $(if $(REOCR_COLLECT_YEAR_DIRS),$(REOCR_COLLECT_YEAR_DIRS),$(sort $(notdir $(patsubst %/,%,$(dir $(patsubst $(LOCAL_PATH_REOCR_INPUT)/%,%,$(LOCAL_REOCR_INPUT_STAMP_FILES)))))))
  $(call log.debug, LOCAL_REOCR_COLLECT_YEAR_DIRS)

LOCAL_reocr_COLLECTED_YEAR_FILES := \
    $(foreach dir,$(LOCAL_REOCR_COLLECT_YEAR_DIRS),$(LOCAL_PATH_reocr_COLLECTED_PAGES)/$(dir).jsonl.bz2)
  $(call log.debug, LOCAL_reocr_COLLECTED_YEAR_FILES)

LOCAL_reocr_COLLECTED_STATS_FILES := \
    $(foreach dir,$(LOCAL_REOCR_COLLECT_YEAR_DIRS),$(LOCAL_PATH_reocr_COLLECTED_STATS)/$(dir).stats.json)
  $(call log.debug, LOCAL_reocr_COLLECTED_STATS_FILES)

reocr-target: sync-reocr-input sync-reocr
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) reocr-files-target

.PHONY: reocr-target

help-processing::
	@echo ""
	@echo "RE-OCR PROCESSING TARGETS:"
	@echo "  reocr-target       # Sync input/output state, validate stale done markers, then process missing issue archives"
	@echo "  reocr-files-target # Process local re-OCR input stamps into page outputs and done markers"
	@echo "                     # Set REOCR_YEARS=1814 to process only selected canonical page years"
	@echo "  collect-reocr-year # Collect page-level re-OCR JSON into newspaper-year JSONL.bz2 files"
	@echo "                     # Set REOCR_COLLECT_YEARS=1814, or reuse REOCR_YEARS; empty means all local synced years"
	@echo "  collect-reocr-stats # Report page integration counts without writing collected page archives"
	@echo "  collection-reocr-stats # Report re-OCR coverage stats for all listed newspapers"

reocr-files-target: $(LOCAL_reocr_DONE_FILES)
	@if [ -z "$(strip $(LOCAL_REOCR_INPUT_STAMP_FILES))" ]; then \
	  echo "ERROR: No re-OCR issue archives discovered after input sync (REOCR_YEARS=$(REOCR_YEARS))"; \
	  exit 1; \
	fi
	@echo "Re-OCR issue archives selected: $(words $(LOCAL_REOCR_INPUT_STAMP_FILES)) (REOCR_YEARS=$(if $(REOCR_YEARS),$(REOCR_YEARS),all))"

.PHONY: reocr-files-target

collect-reocr-year: sync-reocr-input
	@if [ -z "$(strip $(LOCAL_REOCR_COLLECT_YEAR_DIRS))" ]; then \
	  echo "ERROR: No re-OCR input years available for collect-reocr-year"; \
	  exit 1; \
	fi
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) reocr-collect-files-target

.PHONY: collect-reocr-year

collect-reocr: collect-reocr-year

.PHONY: collect-reocr

reocr-collect-files-target: $(LOCAL_reocr_COLLECTED_YEAR_FILES)

.PHONY: reocr-collect-files-target

collect-reocr-stats: sync-reocr-input
	@if [ -z "$(strip $(LOCAL_REOCR_COLLECT_YEAR_DIRS))" ]; then \
	  echo "ERROR: No re-OCR input years available for collect-reocr-stats"; \
	  exit 1; \
	fi
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) reocr-collect-stats-target

.PHONY: collect-reocr-stats

reocr-collect-stats-target: $(LOCAL_reocr_COLLECTED_STATS_FILES)

.PHONY: reocr-collect-stats-target

validate-reocr-done-markers: $(LOCAL_reocr_SYNC_STAMP_FILES) sync-reocr-pages
	$(MAKE_SILENCE_RECIPE) \
	if [ -d "$(LOCAL_PATH_reocr_STAMPS)" ]; then \
	  $(PYTHON) lib/validate_reocr_done_markers.py \
	    --done-root $(LOCAL_PATH_reocr_STAMPS) \
	    --pages-root $(LOCAL_PATH_reocr_PAGES) \
	    $(foreach dir,$(REOCR_INPUT_YEAR_DIRS),--year-segment $(dir)) \
	    --log-level $(LOGGING_LEVEL); \
	fi

.PHONY: validate-reocr-done-markers

collection-reocr-stats: check-parallel newspaper-list-target
	# tail -f $(BUILD_DIR)/collection-reocr-stats.joblog to monitor per newspaper progress summary
	tr -s '[:space:]' '\n'  < $(NEWSPAPERS_TO_PROCESS_FILE) | \
	parallel  --tag -v \
	   --progress \
	   --joblog $(BUILD_DIR)/collection-reocr-stats.joblog \
	   --jobs $(COLLECTION_JOBS) \
	   --delay $(PARALLEL_DELAY) \
	   --memfree 1G \
	   --load $(MAX_LOAD) \
	   $(PARALLEL_HALT) \
	   "NEWSPAPER={} $(MAKE) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) -k -j --max-load $(MAX_LOAD) collect-reocr-stats"

.PHONY: collection-reocr-stats

$(LOCAL_PATH_reocr_STAMPS)/%.done: $(LOCAL_PATH_REOCR_INPUT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) $(dir $(LOCAL_PATH_reocr_LOGS)/$*.log.gz) $(LOCAL_PATH_reocr_WORK) && \
	echo "Starting re-OCR issue $*: input=$(call LocalToS3,$<) done=$@ log=$(LOCAL_PATH_reocr_LOGS)/$*.log.gz output=$(S3_PATH_reocr)" && \
	set +e; \
	$(PYTHON) lib/cli_reocr.py \
	  --input $(call LocalToS3,$<) \
	  --output-prefix $(S3_PATH_reocr) \
	  --work-root $(LOCAL_PATH_reocr_WORK) \
	  --done-marker $@ \
	  --tesseract-repo $(HF_TESSERACT_REPO_reocr) \
	  --tesseract-model $(HF_TESSERACT_MODEL_reocr) \
	  $(if $(TESSERACT_MODEL_URL_reocr),--tesseract-model-url $(TESSERACT_MODEL_URL_reocr)) \
	  $(if $(HF_FONT_REPO_reocr),--font-repo $(HF_FONT_REPO_reocr)) \
	  $(if $(HF_FONT_MODEL_reocr),--font-model $(HF_FONT_MODEL_reocr)) \
	  --run-id $(RUN_ID_reocr) \
	  --sleep-after $(REOCR_SLEEP_AFTER) \
	  --fallback-confidence $(REOCR_FALLBACK_CONFIDENCE) \
	  --fallback-diff-ratio $(REOCR_FALLBACK_DIFF_RATIO) \
	  --skew-threshold $(REOCR_SKEW_THRESHOLD) \
	  --line-margin-extend $(REOCR_LINE_MARGIN_EXTEND) \
	  --vertical-margin-reduce $(REOCR_VERTICAL_MARGIN_REDUCE) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_NO_SKEW)),--no-skew) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_NO_PSM)),--no-psm) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_MASK_TOKENS)),--mask-tokens) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_DEBUG)),--debug) \
	  --log-level $(LOGGING_LEVEL) \
	  --log-file $(LOCAL_PATH_reocr_LOGS)/$*.log.gz ; \
	status=$$?; \
	set -e; \
	if [ $$status -eq 2 ]; then \
	  echo "No new re-OCR pages computed for $*; keeping local done marker and skipping log/done S3 sync"; \
	elif [ $$status -eq 0 ]; then \
	  $(PYTHON) -m impresso_cookbook.local_to_s3 \
	    $(LOCAL_PATH_reocr_LOGS)/$*.log.gz $(S3_PATH_reocr_LOGS)/$*.log.gz \
	    $@ $(S3_PATH_reocr_STAMPS)/$*.done ; \
	else \
	  rm -vf $@ ; \
	  exit $$status ; \
	fi

$(LOCAL_PATH_reocr_COLLECTED_PAGES)/%.jsonl.bz2: $(LOCAL_PATH_REOCR_INPUT)/%.last_synced
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) $(LOCAL_PATH_reocr_COLLECTED_STATS) $(LOCAL_PATH_reocr_COLLECTED_LOGS) $(LOCAL_PATH_reocr_COLLECTED_STAMPS) && \
	$(PYTHON) lib/cli_reocr_collect_year.py \
	  --canonical-input-prefix $(S3_PATH_REOCR_INPUT)/$* \
	  --reocr-prefix $(S3_PATH_reocr) \
	  --output $@ \
	  --stats-output $(LOCAL_PATH_reocr_COLLECTED_STATS)/$*.stats.json \
	  --done-marker $(LOCAL_PATH_reocr_COLLECTED_STAMPS)/$*.done \
	  --year-segment $* \
	  --run-id $(RUN_ID_reocr) \
	  $(if $(HF_FONT_REPO_reocr),--font-repo $(HF_FONT_REPO_reocr)) \
	  $(if $(HF_FONT_MODEL_reocr),--font-model $(HF_FONT_MODEL_reocr)) \
	  --normalization-profile $(REOCR_NORMALIZATION_PROFILE) \
	  $(if $(REOCR_NORMALIZATION_CONFIG),--normalization-config $(REOCR_NORMALIZATION_CONFIG)) \
	  $(if $(filter 0 false FALSE no NO,$(REOCR_SYNTHESIZE_FALLBACK_LINES)),--no-synthesize-fallback-lines) \
	  --log-level $(LOGGING_LEVEL) \
	  --log-file $(LOCAL_PATH_reocr_COLLECTED_LOGS)/$*.log.gz \
	&& \
	$(PYTHON) -m impresso_cookbook.local_to_s3 \
	  --set-timestamp --log-level $(LOGGING_LEVEL) \
	  $@ $(S3_PATH_reocr_COLLECTED_PAGES)/$*.jsonl.bz2 \
	  $(LOCAL_PATH_reocr_COLLECTED_STATS)/$*.stats.json $(S3_PATH_reocr_COLLECTED_STATS)/$*.stats.json \
	  $(LOCAL_PATH_reocr_COLLECTED_LOGS)/$*.log.gz $(S3_PATH_reocr_COLLECTED_LOGS)/$*.log.gz \
	  $(LOCAL_PATH_reocr_COLLECTED_STAMPS)/$*.done $(S3_PATH_reocr_COLLECTED_STAMPS)/$*.done \
	|| { rm -vf $@ $(LOCAL_PATH_reocr_COLLECTED_STATS)/$*.stats.json $(LOCAL_PATH_reocr_COLLECTED_STAMPS)/$*.done ; exit 1; }

$(LOCAL_PATH_reocr_COLLECTED_STATS)/%.stats.json: $(LOCAL_PATH_REOCR_INPUT)/%.last_synced
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) $(LOCAL_PATH_reocr_COLLECTED_LOGS) && \
	$(PYTHON) lib/cli_reocr_collect_year.py \
	  --canonical-input-prefix $(S3_PATH_REOCR_INPUT)/$* \
	  --reocr-prefix $(S3_PATH_reocr) \
	  --stats-only \
	  --stats-output $@ \
	  --year-segment $* \
	  --run-id $(RUN_ID_reocr) \
	  $(if $(HF_FONT_REPO_reocr),--font-repo $(HF_FONT_REPO_reocr)) \
	  $(if $(HF_FONT_MODEL_reocr),--font-model $(HF_FONT_MODEL_reocr)) \
	  --normalization-profile $(REOCR_NORMALIZATION_PROFILE) \
	  $(if $(REOCR_NORMALIZATION_CONFIG),--normalization-config $(REOCR_NORMALIZATION_CONFIG)) \
	  $(if $(filter 0 false FALSE no NO,$(REOCR_SYNTHESIZE_FALLBACK_LINES)),--no-synthesize-fallback-lines) \
	  --log-level $(LOGGING_LEVEL) \
	  --log-file $(LOCAL_PATH_reocr_COLLECTED_LOGS)/$*.stats.log.gz \
	&& \
	$(PYTHON) -m impresso_cookbook.local_to_s3 \
	  --set-timestamp --log-level $(LOGGING_LEVEL) \
	  $@ $(S3_PATH_reocr_COLLECTED_STATS)/$*.stats.json \
	  $(LOCAL_PATH_reocr_COLLECTED_LOGS)/$*.stats.log.gz $(S3_PATH_reocr_COLLECTED_LOGS)/$*.stats.log.gz \
	|| { rm -vf $@ ; exit 1; }

$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_reocr.mk)
