$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_consolidatedcanonical.mk)

###############################################################################
# SYNC consolidatedcanonical processing TARGETS
# Targets for synchronizing data for consolidatedcanonical processing
#
# This module synchronizes three types of data:
# 1. Canonical input data (issues and pages/audios) from s3://112-canonical-final/CANONICAL_PATH_SEGMENT/
#    (synced via sync-canonical target from sync_canonical.mk)
# 2. Langident/OCRQA enrichment data from s3://115-canonical-processed-final/langident/RUN_ID/CANONICAL_PATH_SEGMENT/
#    (synced via sync-langident target from sync_langident.mk)
# 3. Consolidated output data from s3://118-canonical-consolidated-final/VERSION/CANONICAL_PATH_SEGMENT/
#    (synced via sync-consolidatedcanonical target below - issues and selected record stamps)
#
# PATH STRUCTURE:
# ==============
# The consolidated canonical structure mirrors the canonical structure with a VERSION prefix:
#
# Canonical input:  s3://112-canonical-final/CANONICAL_PATH_SEGMENT/issues/
#                   s3://112-canonical-final/CANONICAL_PATH_SEGMENT/pages/
#                   s3://112-canonical-final/CANONICAL_PATH_SEGMENT/audios/
# Enrichment:       s3://115-canonical-processed-final/langident/RUN_ID/CANONICAL_PATH_SEGMENT/
# Consolidated out: s3://118-canonical-consolidated-final/VERSION/CANONICAL_PATH_SEGMENT/issues/
#                   s3://118-canonical-consolidated-final/VERSION/CANONICAL_PATH_SEGMENT/pages/
#                   s3://118-canonical-consolidated-final/VERSION/CANONICAL_PATH_SEGMENT/audios/
#
# Where CANONICAL_PATH_SEGMENT can be:
#   - PROVIDER/NEWSPAPER (e.g., BL/WTCH) when NEWSPAPER_HAS_PROVIDER=1
#   - NEWSPAPER (e.g., WTCH) when NEWSPAPER_HAS_PROVIDER=0
###############################################################################


# VARIABLE: LOCAL_CONSOLIDATEDCANONICAL_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of processed consolidatedcanonical processing data
LOCAL_CONSOLIDATEDCANONICAL_SYNC_STAMP_FILE := $(LOCAL_PATH_CONSOLIDATEDCANONICAL).last_synced
  $(call log.debug, LOCAL_CONSOLIDATEDCANONICAL_SYNC_STAMP_FILE)

# VARIABLE: LOCAL_CONSOLIDATEDCANONICAL_PAGES_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of consolidated pages data
LOCAL_CONSOLIDATEDCANONICAL_PAGES_SYNC_STAMP_FILE := $(LOCAL_PATH_CONSOLIDATEDCANONICAL_PAGES).last_synced
  $(call log.debug, LOCAL_CONSOLIDATEDCANONICAL_PAGES_SYNC_STAMP_FILE)

# VARIABLE: LOCAL_CONSOLIDATEDCANONICAL_AUDIOS_SYNC_STAMP_FILE
# Stamp file indicating last successful synchronization of consolidated audios data
LOCAL_CONSOLIDATEDCANONICAL_AUDIOS_SYNC_STAMP_FILE := $(LOCAL_PATH_CONSOLIDATEDCANONICAL_AUDIOS).last_synced
  $(call log.debug, LOCAL_CONSOLIDATEDCANONICAL_AUDIOS_SYNC_STAMP_FILE)

# VARIABLE: LOCAL_CONSOLIDATEDCANONICAL_RECORD_SYNC_STAMP_FILES
# Selected output record sync stamps. Auto mode syncs both layouts.
ifeq ($(CANONICAL_INPUT_KIND),audios)
LOCAL_CONSOLIDATEDCANONICAL_RECORD_SYNC_STAMP_FILES := $(LOCAL_CONSOLIDATEDCANONICAL_AUDIOS_SYNC_STAMP_FILE)
else ifeq ($(CANONICAL_INPUT_KIND),pages)
LOCAL_CONSOLIDATEDCANONICAL_RECORD_SYNC_STAMP_FILES := $(LOCAL_CONSOLIDATEDCANONICAL_PAGES_SYNC_STAMP_FILE)
else
LOCAL_CONSOLIDATEDCANONICAL_RECORD_SYNC_STAMP_FILES := $(LOCAL_CONSOLIDATEDCANONICAL_PAGES_SYNC_STAMP_FILE) $(LOCAL_CONSOLIDATEDCANONICAL_AUDIOS_SYNC_STAMP_FILE)
endif
  $(call log.debug, LOCAL_CONSOLIDATEDCANONICAL_RECORD_SYNC_STAMP_FILES)


# STAMPED-FILE-RULE: $(LOCAL_PATH_CONSOLIDATEDCANONICAL).last_synced
#: Synchronizes consolidated issues output data from S3 to the local directory (for resume scenarios)
#: Issue outputs are real local file targets downstream, unlike pages which are represented by local stamp targets.
#: Therefore issues are synced in per-file mode, creating empty timestamp-only local placeholders
#: at the exact target paths for remote issue objects, while pages continue to use per-directory
#: .stamp files in the separate pages sync rule below.
$(LOCAL_CONSOLIDATEDCANONICAL_SYNC_STAMP_FILE):
	mkdir -p $(@D) && \
	python -m impresso_cookbook.s3_to_local_stamps  \
	   $(S3_PATH_CONSOLIDATEDCANONICAL) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-file \
	   --remove-dangling-stamps \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& \
	touch $@


# STAMPED-FILE-RULE: $(LOCAL_PATH_CONSOLIDATEDCANONICAL_PAGES).last_synced
#: Synchronizes consolidated pages output data from S3 to the local directory (for resume scenarios)
#: Creates directory stamps with .stamp suffix (hard-coded) for yearly page directories
$(LOCAL_CONSOLIDATEDCANONICAL_PAGES_SYNC_STAMP_FILE):
	mkdir -p $(@D) && \
	python -m impresso_cookbook.s3_to_local_stamps  \
	   $(S3_PATH_CONSOLIDATEDCANONICAL_PAGES) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-directory \
	   --remove-dangling-stamps \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& \
	touch $@

# STAMPED-FILE-RULE: $(LOCAL_PATH_CONSOLIDATEDCANONICAL_AUDIOS).last_synced
#: Synchronizes consolidated audio output data from S3 to the local directory (for resume scenarios)
#: Creates directory stamps with .stamp suffix (hard-coded) for yearly audio directories
$(LOCAL_CONSOLIDATEDCANONICAL_AUDIOS_SYNC_STAMP_FILE):
	mkdir -p $(@D) && \
	python -m impresso_cookbook.s3_to_local_stamps  \
	   $(S3_PATH_CONSOLIDATEDCANONICAL_AUDIOS) \
	   --local-dir $(BUILD_DIR) \
	   --stamp-mode per-directory \
	   --remove-dangling-stamps \
	   --logfile $@.log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& \
	touch $@


# TARGET: sync-consolidatedcanonical-langident
#: Synchronizes final langident/OCRQA enrichments required for consolidation
sync-consolidatedcanonical-langident:
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) -B $(LOCAL_LANGIDENT_SYNC_STAMP_FILE)

.PHONY: sync-consolidatedcanonical-langident


# TARGET: sync-consolidatedcanonical-input
#: Synchronizes input data (canonical + final langident enrichments) required for consolidation
sync-consolidatedcanonical-input: sync-canonical sync-consolidatedcanonical-langident

.PHONY: sync-consolidatedcanonical-input


# TARGET: sync-consolidatedcanonical
#: Synchronizes consolidatedcanonical processing data from/to S3
sync-consolidatedcanonical:
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) -B $(LOCAL_CONSOLIDATEDCANONICAL_SYNC_STAMP_FILE) $(LOCAL_CONSOLIDATEDCANONICAL_RECORD_SYNC_STAMP_FILES)

.PHONY: sync-consolidatedcanonical

# DOUBLE-COLON-TARGET: clean-sync
#: Cleans up synchronized consolidatedcanonical processing data
clean-sync:: clean-sync-consolidatedcanonical

# TARGET: clean-sync-consolidatedcanonical
#: Removes only local synchronization marker files for consolidatedcanonical processing
#: Keeps per-file issue placeholders and mirrored page stamps in place
#: so downstream targets are not needlessly invalidated.
clean-sync-consolidatedcanonical:
	rm -vf \
	  $(LOCAL_CONSOLIDATEDCANONICAL_SYNC_STAMP_FILE) \
	  $(LOCAL_CONSOLIDATEDCANONICAL_SYNC_STAMP_FILE).log.gz \
	  $(LOCAL_CONSOLIDATEDCANONICAL_PAGES_SYNC_STAMP_FILE) \
	  $(LOCAL_CONSOLIDATEDCANONICAL_PAGES_SYNC_STAMP_FILE).log.gz \
	  $(LOCAL_CONSOLIDATEDCANONICAL_AUDIOS_SYNC_STAMP_FILE) \
	  $(LOCAL_CONSOLIDATEDCANONICAL_AUDIOS_SYNC_STAMP_FILE).log.gz \
	  || true

# Optional hard reset target
purge-sync-consolidatedcanonical:
	rm -vrf $(LOCAL_PATH_CONSOLIDATEDCANONICAL) || true
.PHONY: clean-sync-consolidatedcanonical purge-sync-consolidatedcanonical

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_consolidatedcanonical.mk)
