$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_rebuilt.mk)

###############################################################################
# SYNC REBUILT DATA TARGETS
# Targets for synchronizing rebuilt data from S3 to local storage
###############################################################################


# Local synchronization stamp file for rebuilt input data
LOCAL_REBUILT_SYNC_STAMP_FILE := $(LOCAL_PATH_REBUILT).last_synced
  $(call log.debug, LOCAL_REBUILT_SYNC_STAMP_FILE)

# TARGET: sync-rebuilt
# Synchronizes rebuilt input data from S3 to local directory
sync-rebuilt: $(LOCAL_REBUILT_SYNC_STAMP_FILE)

.PHONY: sync-rebuilt

help-sync::
	@echo ""
	@echo "REBUILT INPUT SYNC:"
	@echo "  sync-rebuilt    # Synchronize rebuilt input data from S3 to local stamp files"


# Rule to sync the input data from the S3 bucket to the local directory
# Creates file stamps matching S3 object names exactly (no suffix)
$(LOCAL_PATH_REBUILT).last_synced:
	mkdir -p $(@D) && \
	python -m impresso_cookbook.s3_to_local_stamps\
	   $(S3_PATH_REBUILT) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --logfile $@.log.gz && \
	touch $@



$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_rebuilt.mk)
