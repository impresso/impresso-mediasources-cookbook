$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_nel.mk)

###############################################################################
# SYNC nel processing TARGETS
# Targets for synchronizing processed nel processing data between S3 and local storage
###############################################################################



# VARIABLE: LOCAL_NEL_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of processed nel processing data
LOCAL_NEL_SYNC_STAMP_FILE := $(LOCAL_PATH_NEL).last_synced
  $(call log.debug, LOCAL_NEL_SYNC_STAMP_FILE)

# STAMPED-FILE-RULE: $(LOCAL_PATH_NEL).last_synced
#: Synchronizes data from S3 to the local directory
#: Creates file stamps matching S3 object names exactly (no suffix)
$(LOCAL_PATH_NEL).last_synced:
	mkdir -p $(@D) \
	&& \
	python -m impresso_cookbook.s3_to_local_stamps  \
	   $(S3_PATH_NEL) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --logfile $@.log.gz \
	&& \
	touch $@

# TARGET: sync-nel
#: Synchronizes nel processing data from/to S3
sync-nel: $(LOCAL_NEL_SYNC_STAMP_FILE)

.PHONY: sync-nel

# TARGET: clean-sync
#: Cleans up synchronized nel processing data
clean-sync:: clean-sync-nel

# TARGET: clean-sync-nel
#: Removes local synchronization stamp files for nel processing
clean-sync-nel:
	rm -vrf $(LOCAL_NEL_SYNC_STAMP_FILE) $(LOCAL_PATH_NEL) || true

.PHONY: clean-sync-nel

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_nel.mk)
