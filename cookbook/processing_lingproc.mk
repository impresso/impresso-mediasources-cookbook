$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_lingproc.mk)
###############################################################################
# LINGUISTIC PROCESSING TARGETS
# Targets for processing newspaper content with linguistic analysis
###############################################################################

# DOUBLE-COLON-TARGET: lingproc-target
processing-target :: lingproc-target


sync-input :: sync-rebuilt


sync-output :: sync-lingproc


# === USER-CONFIGURABLE VARIABLES =============================================

# USER-VARIABLE: LINGPROC_LOGGING_LEVEL
# Option to specify logging level for linguistic processing.
#
# Uses the global LOGGING_LEVEL as default, can be overridden for lingproc-specific logging.
LINGPROC_LOGGING_LEVEL ?= $(LOGGING_LEVEL)
  $(call log.debug, LINGPROC_LOGGING_LEVEL)

# USER-VARIABLE: LINGPROC_VALIDATE_OPTION
# Option to enable schema validation of the output
#
# Set to no value or $(EMPTY) for preventing JSON schema validation
# LINGPROC_VALIDATE_OPTION ?= $(EMPTY)
LINGPROC_VALIDATE_OPTION ?= --validate
  $(call log.debug, LINGPROC_VALIDATE_OPTION)

# USER-VARIABLE: LINGPROC_QUIET_OPTION
# Reserved for quiet processing mode (@TODO: Implement in script)
LINGPROC_QUIET_OPTION ?= 
  $(call log.debug, LINGPROC_QUIET_OPTION)

# === USER-CONFIGURABLE VARIABLES (Work-In-Progress Management) ===============

# USER-VARIABLE: LINGPROC_WIP_ENABLED
# Option to enable work-in-progress (WIP) file management to prevent concurrent processing.
#
# Set to 1 to enable WIP checks, or leave empty to disable
# When enabled, the system will:
# - Check for existing WIP files on S3 before starting processing
# - Create WIP files to signal work in progress
# - Remove stale WIP files (older than LINGPROC_WIP_MAX_AGE)
# - Remove WIP files after successful completion
LINGPROC_WIP_ENABLED ?= 1
  $(call log.debug, LINGPROC_WIP_ENABLED)

# USER-VARIABLE: LINGPROC_WIP_MAX_AGE
# Maximum age in hours for WIP files before considering them stale.
#
# If a WIP file is older than this value, it will be removed and processing can proceed.
# Can be fractional (e.g., 0.1 for 6 minutes, useful for testing).
# Default: 1 hour
LINGPROC_WIP_MAX_AGE ?= 1
  $(call log.debug, LINGPROC_WIP_MAX_AGE)

# USER-VARIABLE: LINGPROC_UPLOAD_IF_NEWER_OPTION
# Option to control S3 upload behavior based on timestamps.
#
# Set to --upload-if-newer to upload only if local timestamp is newer than S3,
# or leave empty to skip upload (file metadata only will be updated).
# Note: Without --force-write, files are not uploaded to S3 by default.
# This is useful when you want to update S3 when local files have changed without
# forcing overwrite of content-wise unchanged files.
# LINGPROC_UPLOAD_IF_NEWER_OPTION ?= --upload-if-newer
LINGPROC_UPLOAD_IF_NEWER_OPTION ?=
  $(call log.debug, LINGPROC_UPLOAD_IF_NEWER_OPTION)

# === INTERNAL COMPUTED VARIABLES ==============================================


# VARIABLE: LOCAL_REBUILT_STAMP_FILES
# Stores all locally available rebuilt stamp files for dependency tracking
# Rebuilt stamps match S3 file names exactly (no suffix)
LOCAL_REBUILT_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


# FUNCTION: LocalRebuiltToLingprocFile
# Converts a local rebuilt stamp file name to a local linguistic processing file name
# Rebuilt stamps match S3 file names exactly (no suffix)
define LocalRebuiltToLingprocFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_LINGPROC)/%.jsonl.bz2)
endef


# VARIABLE: LOCAL_LINGPROC_FILES
# Stores the list of linguistic processing files based on rebuilt stamp files
LOCAL_LINGPROC_FILES := \
    $(call LocalRebuiltToLingprocFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_LINGPROC_FILES)

# TARGET: lingproc-target
#: Processes newspaper content with linguistic analysis
#
# Just uses the local data that is there, does not enforce synchronization
lingproc-target: $(LOCAL_LINGPROC_FILES)

.PHONY: lingproc-target

help-processing::
	@echo "LINGUISTIC PROCESSING:"
	@echo "  lingproc-target   # Process rebuilt newspaper content with linguistic analysis"
	@echo "                    # Also contributes to processing-target"
	@echo ""
	@echo "LINGPROC VARIABLES:"
	@echo "  LINGPROC_LOGGING_LEVEL=$(LINGPROC_LOGGING_LEVEL)"
	@echo "  LINGPROC_VALIDATE_OPTION=$(LINGPROC_VALIDATE_OPTION)"
	@echo "  LINGPROC_WIP_ENABLED=$(LINGPROC_WIP_ENABLED)"
	@echo "  LINGPROC_WIP_MAX_AGE=$(LINGPROC_WIP_MAX_AGE)"
	@echo "  LINGPROC_UPLOAD_IF_NEWER_OPTION=$(LINGPROC_UPLOAD_IF_NEWER_OPTION)"

LINGPROC_LANGIDENT_NEEDED ?= 1
  $(call log.debug, LINGPROC_LANGIDENT_NEEDED)


ifeq ($(LINGPROC_LANGIDENT_NEEDED),1)
# FILE-RULE: $(LOCAL_PATH_LINGPROC)/%.jsonl.bz2
#: Rule to process a single newspaper with language identification
#: Rebuilt stamps match S3 file names exactly (no suffix to strip)
$(LOCAL_PATH_LINGPROC)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2 $(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) \
  && \
  $(if $(LINGPROC_WIP_ENABLED), \
  python3 -m impresso_cookbook.local_to_s3 \
    --s3-file-exists $(call LocalToS3,$@) \
    --create-wip --wip-max-age $(LINGPROC_WIP_MAX_AGE) \
    --log-level $(LINGPROC_LOGGING_LEVEL) \
    $@ $(call LocalToS3,$@) \
    $@.log.gz $(call LocalToS3,$@).log.gz \
  || { test $$? -eq 2 && exit 0; exit 1; } \
  && , ) \
  python3 lib/spacy_linguistic_processing.py \
    $(call LocalToS3,$<) \
    --lid $(call LocalToS3,$(word 2,$^)) \
    $(LINGPROC_VALIDATE_OPTION) \
    --git-version $(GIT_VERSION) \
    $(LINGPROC_QUIET_OPTION) \
    -o $@ \
    --log-level $(LINGPROC_LOGGING_LEVEL) \
    --log-file $@.log.gz \
  && \
  python3 -m impresso_cookbook.local_to_s3 \
    --set-timestamp $(LINGPROC_UPLOAD_IF_NEWER_OPTION) \
    --log-level $(LINGPROC_LOGGING_LEVEL) \
    $(if $(LINGPROC_WIP_ENABLED),--remove-wip,) \
    $@ $(call LocalToS3,$@) \
    $@.log.gz $(call LocalToS3,$@).log.gz \
  || { rm -vf $@ ; \
       $(if $(LINGPROC_WIP_ENABLED), \
       python3 -m impresso_cookbook.local_to_s3 --remove-wip \
           --log-level $(LINGPROC_LOGGING_LEVEL) \
           $@ $(call LocalToS3,$@) \
           $@.log.gz $(call LocalToS3,$@).log.gz || true ; , ) \
       exit 1 ; }
else
# FILE-RULE: $(LOCAL_PATH_LINGPROC)/%.jsonl.bz2
#: Rule to process a single newspaper without language identification
#: Rebuilt stamps match S3 file names exactly (no suffix to strip)
#: Trusts the lg property inside the rebuilt file
$(LOCAL_PATH_LINGPROC)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) \
  && \
  $(if $(LINGPROC_WIP_ENABLED), \
  python3 -m impresso_cookbook.local_to_s3 \
    --s3-file-exists $(call LocalToS3,$@) \
    --create-wip --wip-max-age $(LINGPROC_WIP_MAX_AGE) \
    --log-level $(LINGPROC_LOGGING_LEVEL) \
    $@ $(call LocalToS3,$@) \
    $@.log.gz $(call LocalToS3,$@).log.gz \
  || { test $$? -eq 2 && exit 0; exit 1; } \
  && , ) \
  python3 lib/spacy_linguistic_processing.py \
    $(call LocalToS3,$<) \
    $(LINGPROC_VALIDATE_OPTION) \
    --max-doc-length 100000 \
    --git-version $(GIT_VERSION) \
    $(LINGPROC_QUIET_OPTION) \
    -o $@ \
    --log-level $(LINGPROC_LOGGING_LEVEL) \
    --log-file $@.log.gz \
  && \
  python3 -m impresso_cookbook.local_to_s3 \
    --set-timestamp $(LINGPROC_UPLOAD_IF_NEWER_OPTION) \
    --log-level $(LINGPROC_LOGGING_LEVEL) \
    $(if $(LINGPROC_WIP_ENABLED),--remove-wip,) \
    $@ $(call LocalToS3,$@) \
    $@.log.gz $(call LocalToS3,$@).log.gz \
  || { rm -vf $@ ; \
       $(if $(LINGPROC_WIP_ENABLED), \
       python3 -m impresso_cookbook.local_to_s3 --remove-wip \
           --log-level $(LINGPROC_LOGGING_LEVEL) \
           $@ $(call LocalToS3,$@) \
           $@.log.gz $(call LocalToS3,$@).log.gz || true ; , ) \
       exit 1 ; }
endif

$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_lingproc.mk)
