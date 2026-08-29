$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_reocr.mk)
###############################################################################
# SYNC reocr processing TARGETS
###############################################################################

$(LOCAL_PATH_REOCR_INPUT).last_synced:
	mkdir -p $(@D) && \
	$(PYTHON) -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_REOCR_INPUT) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& touch $@

$(LOCAL_PATH_REOCR_INPUT)/%.last_synced:
	mkdir -p $(@D) && \
	$(PYTHON) -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_REOCR_INPUT)/$* \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& touch $@

$(LOCAL_PATH_reocr_STAMPS).last_synced:
	mkdir -p $(@D) && \
	$(PYTHON) -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_reocr_STAMPS) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --file-extensions done \
	   --write-content \
	   --remove-dangling-stamps \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& touch $@

$(LOCAL_PATH_reocr_STAMPS)/%.last_synced:
	mkdir -p $(@D) && \
	$(PYTHON) -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_reocr_STAMPS)/$* \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --file-extensions done \
	   --write-content \
	   --remove-dangling-stamps \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& touch $@

$(LOCAL_PATH_reocr_PAGES).last_synced:
	mkdir -p $(@D) && \
	$(PYTHON) -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_reocr_PAGES) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --file-extensions json \
	   --remove-dangling-stamps \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& touch $@

$(LOCAL_PATH_reocr_PAGES)/%.last_synced:
	mkdir -p $(@D) && \
	$(PYTHON) -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_reocr_PAGES)/$* \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --file-extensions json \
	   --remove-dangling-stamps \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& touch $@

$(LOCAL_PATH_reocr_COLLECTED).last_synced:
	mkdir -p $(@D) && \
	$(PYTHON) -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_reocr_COLLECTED) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --file-extensions jsonl.bz2 json done log.gz \
	   --remove-dangling-stamps \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& touch $@

define CheckReocrInputFilesAfterSync
	@set -e; \
	for dir in $(if $(REOCR_INPUT_YEAR_DIRS),$(REOCR_INPUT_YEAR_DIRS),.); do \
	  if [ "$$dir" = "." ]; then \
	    stamp="$(LOCAL_PATH_REOCR_INPUT).last_synced"; \
	    has_files() { find "$(LOCAL_PATH_REOCR_INPUT)" -mindepth 2 -maxdepth 2 -name '*.jsonl.bz2' -print -quit | grep -q .; }; \
	  else \
	    stamp="$(LOCAL_PATH_REOCR_INPUT)/$$dir.last_synced"; \
	    has_files() { find "$(LOCAL_PATH_REOCR_INPUT)/$$dir" -maxdepth 1 -name '*.jsonl.bz2' -print -quit | grep -q .; }; \
	  fi; \
	  if ! has_files; then \
	    echo "No local re-OCR input files found for $$dir after sync; refreshing $$stamp"; \
	    rm -f "$$stamp"; \
	    $(MAKE) -f $(firstword $(MAKEFILE_LIST)) "$$stamp"; \
	  fi; \
	  if ! has_files; then \
	    echo "ERROR: No re-OCR input files found for $$dir after refreshing input sync"; \
	    rm -f "$$stamp"; \
	    exit 1; \
	  fi; \
	done
endef

sync-reocr-input: $(LOCAL_REOCR_INPUT_SYNC_STAMP_FILES)
	$(CheckReocrInputFilesAfterSync)

.PHONY: sync-reocr-input

help-sync::
	@echo ""
	@echo "RE-OCR INPUT SYNC:"
	@echo "  sync-reocr-input # Synchronize re-OCR input issue archives from S3 to local stamp files"
	@echo "                   # Set REOCR_YEARS=1814 to limit sync/processing to one or more years"

sync-reocr: validate-reocr-done-markers

.PHONY: sync-reocr

help-sync::
	@echo ""
	@echo "RE-OCR OUTPUT STATE SYNC:"
	@echo "  sync-reocr       # Synchronize remote re-OCR done markers, validate page coverage, and prune stale local done markers"
	@echo "                   # Set REOCR_YEARS=1814 to limit output-state sync to selected years"

sync-reocr-pages: $(LOCAL_reocr_PAGES_SYNC_STAMP_FILES)

.PHONY: sync-reocr-pages

help-sync::
	@echo "  sync-reocr-pages # Synchronize remote re-OCR page outputs to local stamp files"

sync-reocr-collected: $(LOCAL_reocr_COLLECTED_SYNC_STAMP_FILE)

.PHONY: sync-reocr-collected

help-sync::
	@echo "  sync-reocr-collected # Synchronize collected re-OCR year packages to local stamp files"

clean-sync:: clean-sync-reocr-input clean-sync-reocr-output

clean-sync-input:: clean-sync-reocr-input

clean-sync-output:: clean-sync-reocr-output

clean-sync-reocr-input:
	rm -vrf $(LOCAL_REOCR_INPUT_SYNC_STAMP_FILE) $(LOCAL_PATH_REOCR_INPUT) || true

clean-sync-reocr-output:
	rm -vrf $(LOCAL_reocr_SYNC_STAMP_FILE) $(LOCAL_reocr_PAGES_SYNC_STAMP_FILE) $(LOCAL_reocr_COLLECTED_SYNC_STAMP_FILE) $(LOCAL_PATH_reocr) $(LOCAL_PATH_reocr_COLLECTED) || true

.PHONY: clean-sync-reocr-input clean-sync-reocr-output

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_reocr.mk)
