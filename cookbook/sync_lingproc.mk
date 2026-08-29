$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_lingproc.mk)

###############################################################################
# SYNC LINGUISTIC PROCESSING TARGETS
# Targets for synchronizing processed linguistic data between S3 and local storage
###############################################################################


# DOUBLE-COLON-TARGET: sync-output
# Synchronizes linguistic processing output data
sync-output :: sync-lingproc


# DOUBLE-COLON-TARGET: sync-input
# Synchronizes linguistic processing input data
sync-input :: sync-lingproc


# VARIABLE: LOCAL_LINGPROC_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of processed linguistic data
LOCAL_LINGPROC_SYNC_STAMP_FILE := $(LOCAL_PATH_LINGPROC).last_synced
  $(call log.debug, LOCAL_LINGPROC_SYNC_STAMP_FILE)


# STAMPED-FILE-RULE: $(LOCAL_PATH_LINGPROC).last_synced
#: Synchronizes data from S3 to the local directory
#: Creates file stamps matching S3 object names exactly (no suffix)
$(LOCAL_PATH_LINGPROC).last_synced:
	mkdir -p $(@D) && \
	python  -m impresso_cookbook.s3_to_local_stamps  \
	   $(S3_PATH_LINGPROC) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --logfile $@.log.gz && \
	touch $@


# TARGET: sync-lingproc
#: Synchronizes linguistic processing data from/to S3
sync-lingproc: $(LOCAL_LINGPROC_SYNC_STAMP_FILE)

.PHONY: sync-lingproc

help-sync::
	@echo ""
	@echo "LINGPROC SYNC:"
	@echo "  sync-lingproc   # Synchronize linguistic processing data from/to S3"


# TARGET: clean-sync
#: Cleans up synchronized linguistic processing data
clean-sync:: clean-sync-lingproc


# TARGET: clean-sync-lingproc
#: Removes local synchronization stamp files for linguistic processing
clean-sync-lingproc:
	rm -vrf $(LOCAL_LINGPROC_SYNC_STAMP_FILE) $(LOCAL_PATH_LINGPROC) || true

.PHONY: clean-sync-lingproc

help-clean::
	@echo "  clean-sync-lingproc # Remove local lingproc sync stamp and files"


$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_lingproc.mk)
