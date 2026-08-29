$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_ocrqa.mk)

###############################################################################
# SYNC OCR QUALITY ASSESSMENT TARGETS
# Targets for synchronizing processed OCR quality assessment data between S3 and local storage
###############################################################################


# VARIABLE: LOCAL_OCRQA_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of processed OCR quality assessment data
LOCAL_OCRQA_SYNC_STAMP_FILE := $(LOCAL_PATH_OCRQA).last_synced
  $(call log.debug, LOCAL_OCRQA_SYNC_STAMP_FILE)

# STAMPED-FILE-RULE: $(LOCAL_PATH_OCRQA).last_synced
#: Synchronizes data from S3 to the local directory
#: Creates file stamps matching S3 object names exactly (no suffix)
$(LOCAL_PATH_OCRQA).last_synced:
	mkdir -p $(@D) && \
	python  -m impresso_cookbook.s3_to_local_stamps  \
	   $(S3_PATH_OCRQA) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --logfile $@.log.gz && \
	touch $@

# TARGET: sync-ocrqa
#: Synchronizes OCR quality assessment data from/to S3
sync-ocrqa: $(LOCAL_OCRQA_SYNC_STAMP_FILE)

.PHONY: sync-ocrqa

help-sync::
	@echo ""
	@echo "OCRQA SYNC:"
	@echo "  sync-ocrqa     # Synchronize OCR quality assessment data from/to S3"

# TARGET: clean-sync
#: Cleans up synchronized OCR quality assessment data
clean-sync:: clean-sync-ocrqa

# TARGET: clean-sync-ocrqa
#: Removes local synchronization stamp files for OCR quality assessment
clean-sync-ocrqa:
	rm -vrf $(LOCAL_OCRQA_SYNC_STAMP_FILE) $(LOCAL_PATH_OCRQA) || true

.PHONY: clean-sync-ocrqa

help-clean::
	@echo "  clean-sync-ocrqa # Remove local OCRQA sync stamp and files"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_ocrqa.mk)
