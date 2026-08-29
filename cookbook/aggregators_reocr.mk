$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/aggregators_reocr.mk)
###############################################################################
# RE-OCR AGGREGATORS
# Run-level summaries from existing re-OCR S3 outputs.
###############################################################################

S3_PATH_reocr_RUN_ROOT := s3://$(S3_BUCKET_reocr)/$(PROCESS_LABEL_reocr)$(PROCESS_SUBTYPE_LABEL_reocr)/$(RUN_ID_reocr)
  $(call log.debug, S3_PATH_reocr_RUN_ROOT)

S3_PATH_reocr_AGGREGATED_PREFIX ?= $(S3_PATH_reocr_RUN_ROOT)__AGGREGATED
  $(call log.debug, S3_PATH_reocr_AGGREGATED_PREFIX)

LOCAL_PATH_reocr_AGGREGATED := $(BUILD_DIR)/$(S3_BUCKET_reocr)/$(PROCESS_LABEL_reocr)$(PROCESS_SUBTYPE_LABEL_reocr)/$(RUN_ID_reocr)__AGGREGATED
  $(call log.debug, LOCAL_PATH_reocr_AGGREGATED)

empty :=
space := $(empty) $(empty)

REOCR_AGGREGATE_YEARS ?= $(REOCR_YEARS)
  $(call log.debug, REOCR_AGGREGATE_YEARS)

REOCR_AGGREGATE_NEWSPAPER ?=
  $(call log.debug, REOCR_AGGREGATE_NEWSPAPER)

REOCR_AGGREGATE_PROGRESS_EVERY ?= 10000
  $(call log.debug, REOCR_AGGREGATE_PROGRESS_EVERY)

REOCR_AGGREGATE_INCLUDE_DONE_MARKERS ?= 0
  $(call log.debug, REOCR_AGGREGATE_INCLUDE_DONE_MARKERS)

REOCR_AGGREGATE_FONTCLASS_STATS ?= 0

REOCR_AGGREGATE_WORKERS ?= 8

REOCR_AGGREGATE_FLAT_LISTING ?= 0

REOCR_AGGREGATE_UPLOAD_ENABLED ?= 1

REOCR_AGGREGATE_COMPARE_CONSOLIDATED_ISSUES ?= 1

REOCR_AGGREGATE_CONSOLIDATED_ISSUES_PREFIX ?= s3://118-canonical-consolidated-final/v2025-12-04

REOCR_AGGREGATE_SCOPE_SUFFIX := $(if $(REOCR_AGGREGATE_NEWSPAPER),_np-$(subst /,-,$(REOCR_AGGREGATE_NEWSPAPER)))$(if $(strip $(REOCR_AGGREGATE_YEARS)),_yrs-$(subst $(space),-,$(strip $(REOCR_AGGREGATE_YEARS))))

REOCR_AGGREGATE_PAGES_BASENAME := stats-pages$(REOCR_AGGREGATE_SCOPE_SUFFIX)

REOCR_AGGREGATE_FONTCLASS_BASENAME := stats-fontclass$(REOCR_AGGREGATE_SCOPE_SUFFIX)

REOCR_SAMPLE_PAGES ?= 500
  $(call log.debug, REOCR_SAMPLE_PAGES)

REOCR_SAMPLE_LINES_PER_PAGE ?= 4
  $(call log.debug, REOCR_SAMPLE_LINES_PER_PAGE)

REOCR_SAMPLE_SEED ?= 13
  $(call log.debug, REOCR_SAMPLE_SEED)

REOCR_SAMPLE_LOW_CONFIDENCE ?= 50
  $(call log.debug, REOCR_SAMPLE_LOW_CONFIDENCE)

REOCR_SAMPLE_HIGH_CONFIDENCE ?= 90
  $(call log.debug, REOCR_SAMPLE_HIGH_CONFIDENCE)

REOCR_SAMPLE_PREFIX ?= $(S3_PATH_reocr_RUN_ROOT)
  $(call log.debug, REOCR_SAMPLE_PREFIX)

# TARGET: aggregate-reocr-stats
#: Traverse existing re-OCR output on S3 and aggregate run coverage statistics.
aggregate-reocr-stats:
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(LOCAL_PATH_reocr_AGGREGATED) && \
	$(PYTHON) lib/aggregate_reocr_s3_stats.py \
	  --s3-prefix $(S3_PATH_reocr_RUN_ROOT) \
	  --output $(LOCAL_PATH_reocr_AGGREGATED)/$(REOCR_AGGREGATE_PAGES_BASENAME).jsonl.gz \
	  --run-id $(RUN_ID_reocr) \
	  $(if $(HF_FONT_REPO_reocr),--font-repo $(HF_FONT_REPO_reocr)) \
	  $(if $(HF_FONT_MODEL_reocr),--font-model $(HF_FONT_MODEL_reocr)) \
	  $(if $(REOCR_AGGREGATE_NEWSPAPER),--newspaper $(REOCR_AGGREGATE_NEWSPAPER)) \
	  $(if $(REOCR_AGGREGATE_YEARS),--years $(REOCR_AGGREGATE_YEARS)) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_AGGREGATE_COMPARE_CONSOLIDATED_ISSUES)),--compare-consolidated-issues,--skip-compare-consolidated-issues) \
	  --consolidated-issues-prefix $(REOCR_AGGREGATE_CONSOLIDATED_ISSUES_PREFIX) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_AGGREGATE_FONTCLASS_STATS)),--fontclass-stats,--skip-fontclass-stats) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_AGGREGATE_INCLUDE_DONE_MARKERS)),--include-done-markers,--skip-done-markers) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_AGGREGATE_FLAT_LISTING)),--flat-listing) \
	  --workers $(REOCR_AGGREGATE_WORKERS) \
	  --progress-every $(REOCR_AGGREGATE_PROGRESS_EVERY) \
	  --log-level $(LOGGING_LEVEL) \
	  --log-file $(LOCAL_PATH_reocr_AGGREGATED)/$(REOCR_AGGREGATE_PAGES_BASENAME).log.gz \
	&& \
	if [ "$(REOCR_AGGREGATE_UPLOAD_ENABLED)" = "1" ]; then \
	  $(PYTHON) -m impresso_cookbook.local_to_s3 \
	    --set-timestamp --log-level $(LOGGING_LEVEL) \
	    $(LOCAL_PATH_reocr_AGGREGATED)/$(REOCR_AGGREGATE_PAGES_BASENAME).jsonl.gz $(S3_PATH_reocr_AGGREGATED_PREFIX)_$(REOCR_AGGREGATE_PAGES_BASENAME).jsonl.gz \
	    $(LOCAL_PATH_reocr_AGGREGATED)/$(REOCR_AGGREGATE_PAGES_BASENAME).log.gz $(S3_PATH_reocr_AGGREGATED_PREFIX)_$(REOCR_AGGREGATE_PAGES_BASENAME).log.gz; \
	else \
	  echo "REOCR aggregate upload disabled; keeping local outputs in $(LOCAL_PATH_reocr_AGGREGATED)"; \
	fi

# TARGET: aggregate-reocr-stats-fontclass
#: Traverse existing re-OCR output on S3 and aggregate coverage with fontclass reads enabled.
aggregate-reocr-stats-fontclass: REOCR_AGGREGATE_FONTCLASS_STATS=1
aggregate-reocr-stats-fontclass:
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(LOCAL_PATH_reocr_AGGREGATED) && \
	$(PYTHON) lib/aggregate_reocr_s3_stats.py \
	  --s3-prefix $(S3_PATH_reocr_RUN_ROOT) \
	  --output $(LOCAL_PATH_reocr_AGGREGATED)/$(REOCR_AGGREGATE_FONTCLASS_BASENAME).jsonl.gz \
	  --run-id $(RUN_ID_reocr) \
	  $(if $(HF_FONT_REPO_reocr),--font-repo $(HF_FONT_REPO_reocr)) \
	  $(if $(HF_FONT_MODEL_reocr),--font-model $(HF_FONT_MODEL_reocr)) \
	  $(if $(REOCR_AGGREGATE_NEWSPAPER),--newspaper $(REOCR_AGGREGATE_NEWSPAPER)) \
	  $(if $(REOCR_AGGREGATE_YEARS),--years $(REOCR_AGGREGATE_YEARS)) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_AGGREGATE_COMPARE_CONSOLIDATED_ISSUES)),--compare-consolidated-issues,--skip-compare-consolidated-issues) \
	  --consolidated-issues-prefix $(REOCR_AGGREGATE_CONSOLIDATED_ISSUES_PREFIX) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_AGGREGATE_FONTCLASS_STATS)),--fontclass-stats,--skip-fontclass-stats) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_AGGREGATE_INCLUDE_DONE_MARKERS)),--include-done-markers,--skip-done-markers) \
	  $(if $(filter 1 true TRUE yes YES,$(REOCR_AGGREGATE_FLAT_LISTING)),--flat-listing) \
	  --workers $(REOCR_AGGREGATE_WORKERS) \
	  --progress-every $(REOCR_AGGREGATE_PROGRESS_EVERY) \
	  --log-level $(LOGGING_LEVEL) \
	  --log-file $(LOCAL_PATH_reocr_AGGREGATED)/$(REOCR_AGGREGATE_FONTCLASS_BASENAME).log.gz \
	&& \
	if [ "$(REOCR_AGGREGATE_UPLOAD_ENABLED)" = "1" ]; then \
	  $(PYTHON) -m impresso_cookbook.local_to_s3 \
	    --set-timestamp --log-level $(LOGGING_LEVEL) \
	    $(LOCAL_PATH_reocr_AGGREGATED)/$(REOCR_AGGREGATE_FONTCLASS_BASENAME).jsonl.gz $(S3_PATH_reocr_AGGREGATED_PREFIX)_$(REOCR_AGGREGATE_FONTCLASS_BASENAME).jsonl.gz \
	    $(LOCAL_PATH_reocr_AGGREGATED)/$(REOCR_AGGREGATE_FONTCLASS_BASENAME).log.gz $(S3_PATH_reocr_AGGREGATED_PREFIX)_$(REOCR_AGGREGATE_FONTCLASS_BASENAME).log.gz; \
	else \
	  echo "REOCR aggregate upload disabled; keeping local outputs in $(LOCAL_PATH_reocr_AGGREGATED)"; \
	fi

# TARGET: aggregate-reocr-stats-newspaper
#: Convenience wrapper for newspaper-scoped page aggregation using explicit PROVIDER and NEWSPAPER.
aggregate-reocr-stats-newspaper:
	$(MAKE_SILENCE_RECIPE) \
	if [ -z "$(PROVIDER)" ] || [ -z "$(NEWSPAPER)" ]; then \
	  echo "Set both PROVIDER and NEWSPAPER, e.g. make aggregate-reocr-stats-newspaper PROVIDER=SNL NEWSPAPER=FZG"; \
	  exit 1; \
	fi && \
	$(MAKE) aggregate-reocr-stats REOCR_AGGREGATE_NEWSPAPER=$(PROVIDER)/$(NEWSPAPER)

# TARGET: sample-reocr-lines
#: Sample line-level re-OCR examples from page JSON outputs on S3.
sample-reocr-lines:
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(LOCAL_PATH_reocr_AGGREGATED) && \
	$(PYTHON) lib/sample_reocr_lines.py \
	  --s3-prefix $(REOCR_SAMPLE_PREFIX) \
	  --output $(LOCAL_PATH_reocr_AGGREGATED)/line-sample.jsonl.gz \
	  --pages $(REOCR_SAMPLE_PAGES) \
	  --lines-per-page $(REOCR_SAMPLE_LINES_PER_PAGE) \
	  --low-confidence $(REOCR_SAMPLE_LOW_CONFIDENCE) \
	  --high-confidence $(REOCR_SAMPLE_HIGH_CONFIDENCE) \
	  --seed $(REOCR_SAMPLE_SEED) \
	  --log-level $(LOGGING_LEVEL) \
	  --log-file $(LOCAL_PATH_reocr_AGGREGATED)/line-sample.log.gz \
	&& \
	$(PYTHON) -m impresso_cookbook.local_to_s3 \
	  --set-timestamp --log-level $(LOGGING_LEVEL) \
	  $(LOCAL_PATH_reocr_AGGREGATED)/line-sample.jsonl.gz $(S3_PATH_reocr_AGGREGATED_PREFIX)_line-sample.jsonl.gz \
	  $(LOCAL_PATH_reocr_AGGREGATED)/line-sample.log.gz $(S3_PATH_reocr_AGGREGATED_PREFIX)_line-sample.log.gz

# TARGET: aggregate
#: Conventional cookbook aggregation entry point for re-OCR outputs.
aggregate: aggregate-reocr-stats

.PHONY: aggregate aggregate-reocr-stats aggregate-reocr-stats-fontclass aggregate-reocr-stats-newspaper sample-reocr-lines

help-aggregation::
	@echo "RE-OCR AGGREGATION:"
	@echo "  aggregate-reocr-stats # Fast listing-only page JSON coverage aggregate"
	@echo "                        # Set REOCR_AGGREGATE_NEWSPAPER=PROVIDER/NEWSPAPER or REOCR_AGGREGATE_YEARS='1865 1866' to filter"
	@echo "                        # Writes scoped filenames such as __AGGREGATED_stats-pages_np-SNL-FZG.*"
	@echo "                        # By default also compares against consolidated issue files under $(REOCR_AGGREGATE_CONSOLIDATED_ISSUES_PREFIX)"
	@echo "                        # Set REOCR_AGGREGATE_COMPARE_CONSOLIDATED_ISSUES=0 to skip expected-page comparison"
	@echo "                        # Set REOCR_AGGREGATE_INCLUDE_DONE_MARKERS=1 to also scan stamps"
	@echo "                        # Set REOCR_AGGREGATE_UPLOAD_ENABLED=0 to keep outputs local only"
	@echo "  aggregate-reocr-stats-fontclass # Slower aggregate that downloads page JSON files for fontclass stats"
	@echo "                                  # Writes scoped stats-fontclass filenames and accepts the same filters"
	@echo "  aggregate-reocr-stats-newspaper # Convenience wrapper; pass PROVIDER=<provider> NEWSPAPER=<paper>"
	@echo "  sample-reocr-lines # Randomly sample line-level high/low confidence re-OCR examples"
	@echo "                     # Defaults: REOCR_SAMPLE_PAGES=500 REOCR_SAMPLE_LINES_PER_PAGE=4"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/aggregators_reocr.mk)
