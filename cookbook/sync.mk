$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync.mk)

###############################################################################
# GENERAL SYNC TARGETS
# Targets for synchronizing data between S3 and local storage
# Must be included before any specific sync targets
###############################################################################

# TARGET: check-s3-credentials
#: Checks if the S3 credentials are set in the environment variables
check-s3-credentials:
	. $(abspath .env) ; \
	if [ -n "$${SE_SECRET_KEY}" ] && [ -n "$${SE_ACCESS_KEY}" ] && [ -n "$${SE_HOST_URL}" ] ; then \
		echo "S3 credentials are properly configured"; \
	else \
		echo "SE_SECRET_KEY or SE_ACCESS_KEY is not set. Please set them in your environment variables or local .env file"; \
		exit 1; \
	fi

help-sync::
	@echo "SYNC PREREQUISITES:"
	@echo "  check-s3-credentials # Check if the S3 credentials are set in the environment variables"

.PHONY: check-s3-credentials

# DOUBLE-COLON-TARGET: sync
#: Synchronize local files with S3 (input and output) without deleting local files
#
# This target ensures that both input and output files are synchronized
# with S3 while preserving local files.
sync:: check-s3-credentials | $(BUILD_DIR) 

sync:: sync-output

sync:: sync-input

.PHONY: sync

help-sync::
	@echo ""
	@echo "GENERIC SYNC TARGETS:"
	@echo "  sync            # Synchronize local files with S3 (input and output) without deleting local files"


# DOUBLE-COLON-TARGET: sync-input
#: Synchronize input files with S3 without deleting local files
#
# This target syncs input files from S3 to the local machine
# without removing any existing local files.
sync-input:: | $(BUILD_DIR)

.PHONY: sync-input

help-sync::
	@echo "  sync-input      # Synchronize input files with S3 without deleting local files"


# DOUBLE-COLON-TARGET: sync-output
#: Synchronize output files with S3 without deleting local files
#
# This target ensures that output files are synchronized from the
# local machine to S3 while keeping existing local files intact.
sync-output:: | $(BUILD_DIR)

.PHONY: sync-output

help-sync::
	@echo "  sync-output     # Synchronize output files with S3 without deleting local files"


# DOUBLE-COLON-TARGET: resync-output
#: Synchronize local files with S3 output by deleting all local files first
#
# This target ensures that both input and output files are freshly synchronized
resync-output: clean-sync-output
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) sync-output

.PHONY: resync-output

help-sync::
	@echo "  resync-output   # Delete local output sync state, then synchronize output files"

# DOUBLE-COLON-TARGET: resync-input
#: Synchronize local input with S3 by deleting all local files first
#
# This target ensures that both input and output files are freshly synchronized
resync-input: clean-sync-input
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) sync-input

.PHONY: resync-input

help-sync::
	@echo "  resync-input    # Delete local input sync state, then synchronize input files"

# TARGET: resync
#: Forces complete resynchronization with remote server
resync: resync-input resync-output

.PHONY: resync

help-sync::
	@echo "  resync          # Force complete input and output resynchronization"



# USER-VARIABLE: LOCAL_STAMP_SUFFIX
#: Suffix used for local stamp files to track sync status
#
# This variable can be overridden to provide a specific suffix
# for local stamp files to differentiate sync operations.
# Default is empty (no suffix). Set to .stamp to use .stamp suffix.
LOCAL_STAMP_SUFFIX ?=
  $(call log.debug, LOCAL_STAMP_SUFFIX)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync.mk)
