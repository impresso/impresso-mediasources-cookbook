$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_content_item_classification.mk)

###############################################################################
# SYNC content_item_classification processing TARGETS
# Targets for synchronizing processed content_item_classification processing data between S3 and local storage
###############################################################################


# VARIABLE: LOCAL_content_item_classification_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of processed content_item_classification processing data
LOCAL_content_item_classification_SYNC_STAMP_FILE := $(LOCAL_PATH_content_item_classification).last_synced
  $(call log.debug, LOCAL_content_item_classification_SYNC_STAMP_FILE)

# STAMPED-FILE-RULE: $(LOCAL_PATH_content_item_classification).last_synced
#: Synchronizes data from S3 to the local directory
#: Creates file stamps matching S3 object names exactly (no suffix)
$(LOCAL_PATH_content_item_classification).last_synced:
	mkdir -p $(@D) && \
	python  -m impresso_cookbook.s3_to_local_stamps  \
	   $(S3_PATH_content_item_classification) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --logfile $@.log.gz && \
	touch $@

# TARGET: sync-content_item_classification
#: Synchronizes content_item_classification processing data from/to S3
sync-content_item_classification: $(LOCAL_content_item_classification_SYNC_STAMP_FILE)

.PHONY: sync-content_item_classification

# TARGET: clean-sync
#: Cleans up synchronized content_item_classification processing data
clean-sync:: clean-sync-content_item_classification

# TARGET: clean-sync-content_item_classification
#: Removes local synchronization stamp files for content_item_classification processing
clean-sync-content_item_classification:
	rm -vrf $(LOCAL_content_item_classification_SYNC_STAMP_FILE) $(LOCAL_PATH_content_item_classification) || true

.PHONY: clean-sync-content_item_classification

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_content_item_classification.mk)
