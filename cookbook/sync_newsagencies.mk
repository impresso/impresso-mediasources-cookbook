$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_newsagencies.mk)

###############################################################################
# SYNC newsagencies processing TARGETS
# Targets for synchronizing processed newsagencies processing data between S3 and local storage
###############################################################################



# VARIABLE: LOCAL_NEWSAGENCIES_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of processed newsagencies processing data
LOCAL_NEWSAGENCIES_SYNC_STAMP_FILE := $(LOCAL_PATH_NEWSAGENCIES).last_synced
  $(call log.debug, LOCAL_NEWSAGENCIES_SYNC_STAMP_FILE)

# STAMPED-FILE-RULE: $(LOCAL_PATH_NEWSAGENCIES).last_synced
#: Synchronizes data from S3 to the local directory
#: Creates file stamps matching S3 object names exactly (no suffix)
$(LOCAL_PATH_NEWSAGENCIES).last_synced:
	mkdir -p $(@D) \
	&& \
	python -m impresso_cookbook.s3_to_local_stamps  \
	   $(S3_PATH_NEWSAGENCIES) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --logfile $@.log.gz \
	&& \
	touch $@

# TARGET: sync-newsagencies
#: Synchronizes newsagencies processing data from/to S3
sync-newsagencies: $(LOCAL_NEWSAGENCIES_SYNC_STAMP_FILE)

.PHONY: sync-newsagencies

# TARGET: clean-sync
#: Cleans up synchronized newsagencies processing data
clean-sync:: clean-sync-newsagencies

# TARGET: clean-sync-newsagencies
#: Removes local synchronization stamp files for newsagencies processing
clean-sync-newsagencies:
	rm -vrf $(LOCAL_NEWSAGENCIES_SYNC_STAMP_FILE) $(LOCAL_PATH_NEWSAGENCIES) || true

.PHONY: clean-sync-newsagencies

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_newsagencies.mk)
