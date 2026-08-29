$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_canonical.mk)

###############################################################################
# INPUT PATHS FOR CANONICAL FILES FOR PAGES OF A SPECIFIC NEWSPAPER
#
# Defines paths and variables for accessing newspaper files on S3 in the impresso
# canonical format that are used for local synchronization and processing.
#
# PROVIDER HANDLING:
# ==================
# If NEWSPAPER_HAS_PROVIDER is set to 1, paths include PROVIDER level:
#   - PROVIDER must be set explicitly, or
#   - NEWSPAPER should be in PROVIDER/NEWSPAPER format (e.g., BL/WTCH)
#
# If NEWSPAPER_HAS_PROVIDER is 0, paths use NEWSPAPER directly without PROVIDER.
#
# PROVIDER HANDLING:
# ==================
# If NEWSPAPER_HAS_PROVIDER is set to 1, paths include PROVIDER level:
#   - PROVIDER must be set explicitly, or
#   - NEWSPAPER should be in PROVIDER/NEWSPAPER format (e.g., BL/WTCH)
#
# If NEWSPAPER_HAS_PROVIDER is 0, paths use NEWSPAPER directly without PROVIDER.
###############################################################################

# USER-VARIABLE: S3_BUCKET_CANONICAL
# The bucket for canonical content.
# This variable specifies the S3 bucket where the canonical newspaper files is stored.
S3_BUCKET_CANONICAL ?= 112-canonical-final
S3_BUCKET_CANONICAL ?= 112-canonical-final
  $(call log.debug, S3_BUCKET_CANONICAL)

# USER-VARIABLE: CANONICAL_INPUT_KIND
# Selects which canonical record files should feed processing.
#
# auto: use locally synchronized pages and/or audios stamps
# pages: process canonical page files only
# audios: process canonical audio files only
CANONICAL_INPUT_KIND ?= auto
  $(call log.debug, CANONICAL_INPUT_KIND)

ifneq ($(filter $(CANONICAL_INPUT_KIND),auto pages audios),$(CANONICAL_INPUT_KIND))
  $(error CANONICAL_INPUT_KIND must be one of: auto pages audios)
endif

# USER-VARIABLE: PROVIDER
# The data provider organization (e.g., BL, SWA, NZZ, etc.)
# Required when NEWSPAPER_HAS_PROVIDER=1 and NEWSPAPER doesn't contain provider prefix
# If NEWSPAPER is in PROVIDER/NEWSPAPER format, PROVIDER is extracted automatically
PROVIDER ?=
  $(call log.debug, PROVIDER)

# VARIABLE: CANONICAL_PATH_SEGMENT
# Constructs the path segment based on NEWSPAPER_HAS_PROVIDER flag
# If NEWSPAPER_HAS_PROVIDER=1: Uses PROVIDER/NEWSPAPER or just NEWSPAPER if it contains /
# If NEWSPAPER_HAS_PROVIDER=0: Uses NEWSPAPER directly
ifeq ($(NEWSPAPER_HAS_PROVIDER),1)
  # Check if NEWSPAPER already contains provider (has /)
  ifneq (,$(findstring /,$(NEWSPAPER)))
    CANONICAL_PATH_SEGMENT := $(NEWSPAPER)
  else
    ifneq ($(PROVIDER),)
      CANONICAL_PATH_SEGMENT := $(PROVIDER)/$(NEWSPAPER)
    else
      $(warn PROVIDER must be set when NEWSPAPER_HAS_PROVIDER=1 and NEWSPAPER does not contain provider prefix for any processing steps on newspapers.)
    endif
  endif
else
  CANONICAL_PATH_SEGMENT := $(NEWSPAPER)
endif
  $(call log.debug, CANONICAL_PATH_SEGMENT)

# USER-VARIABLE: PROVIDER
# The data provider organization (e.g., BL, SWA, NZZ, etc.)
# Required when NEWSPAPER_HAS_PROVIDER=1 and NEWSPAPER doesn't contain provider prefix
# If NEWSPAPER is in PROVIDER/NEWSPAPER format, PROVIDER is extracted automatically
PROVIDER ?=
  $(call log.debug, PROVIDER)

# VARIABLE: CANONICAL_PATH_SEGMENT
# Constructs the path segment based on NEWSPAPER_HAS_PROVIDER flag
# If NEWSPAPER_HAS_PROVIDER=1: Uses PROVIDER/NEWSPAPER or just NEWSPAPER if it contains /
# If NEWSPAPER_HAS_PROVIDER=0: Uses NEWSPAPER directly
ifeq ($(NEWSPAPER_HAS_PROVIDER),1)
  # Check if NEWSPAPER already contains provider (has /)
  ifneq (,$(findstring /,$(NEWSPAPER)))
    CANONICAL_PATH_SEGMENT := $(NEWSPAPER)
  else
    ifneq ($(PROVIDER),)
      CANONICAL_PATH_SEGMENT := $(PROVIDER)/$(NEWSPAPER)
    else
      $(warn PROVIDER must be set when NEWSPAPER_HAS_PROVIDER=1 and NEWSPAPER does not contain provider prefix for any processing steps on newspapers.)
    endif
  endif
else
  CANONICAL_PATH_SEGMENT := $(NEWSPAPER)
endif
  $(call log.debug, CANONICAL_PATH_SEGMENT)

# VARIABLE: S3_PATH_CANONICAL_PAGES
# The full S3 path for the canonical pages files of a specific newspaper.
# Structure: s3://112-canonical-final/PROVIDER/NEWSPAPER/pages (with provider)
#        or: s3://112-canonical-final/NEWSPAPER/pages (without provider)
# Structure: s3://112-canonical-final/PROVIDER/NEWSPAPER/pages (with provider)
#        or: s3://112-canonical-final/NEWSPAPER/pages (without provider)

S3_PATH_CANONICAL_PAGES := s3://$(S3_BUCKET_CANONICAL)/$(CANONICAL_PATH_SEGMENT)/pages
S3_PATH_CANONICAL_PAGES := s3://$(S3_BUCKET_CANONICAL)/$(CANONICAL_PATH_SEGMENT)/pages
  $(call log.debug, S3_PATH_CANONICAL_PAGES)

# VARIABLE: S3_PATH_CANONICAL_AUDIOS
# The full S3 path for canonical audio record files of a specific radio source.
# Structure: s3://112-canonical-final/PROVIDER/SOURCE/audios (with provider)
#        or: s3://112-canonical-final/SOURCE/audios (without provider)
S3_PATH_CANONICAL_AUDIOS := s3://$(S3_BUCKET_CANONICAL)/$(CANONICAL_PATH_SEGMENT)/audios
  $(call log.debug, S3_PATH_CANONICAL_AUDIOS)

# VARIABLE: S3_PATH_CANONICAL_ISSUES
# The full S3 path for the canonical issues files of a specific newspaper.
# Structure: s3://112-canonical-final/PROVIDER/NEWSPAPER/issues (with provider)
#        or: s3://112-canonical-final/NEWSPAPER/issues (without provider)

S3_PATH_CANONICAL_ISSUES := s3://$(S3_BUCKET_CANONICAL)/$(CANONICAL_PATH_SEGMENT)/issues
  $(call log.debug, S3_PATH_CANONICAL_ISSUES)

# VARIABLE: S3_PATH_CANONICAL_ISSUES
# The full S3 path for the canonical issues files of a specific newspaper.
# Structure: s3://112-canonical-final/PROVIDER/NEWSPAPER/issues (with provider)
#        or: s3://112-canonical-final/NEWSPAPER/issues (without provider)

S3_PATH_CANONICAL_ISSUES := s3://$(S3_BUCKET_CANONICAL)/$(CANONICAL_PATH_SEGMENT)/issues
  $(call log.debug, S3_PATH_CANONICAL_ISSUES)

# VARIABLE: LOCAL_PATH_CANONICAL_PAGES
# The corresponding local path for canonical newspaper pages files.
# This local directory mirrors the S3 path structure for local builds and processing.
LOCAL_PATH_CANONICAL_PAGES := $(BUILD_DIR)/$(S3_BUCKET_CANONICAL)/$(CANONICAL_PATH_SEGMENT)/pages
LOCAL_PATH_CANONICAL_PAGES := $(BUILD_DIR)/$(S3_BUCKET_CANONICAL)/$(CANONICAL_PATH_SEGMENT)/pages
  $(call log.debug, LOCAL_PATH_CANONICAL_PAGES)

# VARIABLE: LOCAL_PATH_CANONICAL_AUDIOS
# The corresponding local stamp path for canonical audio record files.
LOCAL_PATH_CANONICAL_AUDIOS := $(BUILD_DIR)/$(S3_BUCKET_CANONICAL)/$(CANONICAL_PATH_SEGMENT)/audios
  $(call log.debug, LOCAL_PATH_CANONICAL_AUDIOS)

# VARIABLE: LOCAL_PATH_CANONICAL_ISSUES
# The corresponding local path for canonical newspaper issues files.
LOCAL_PATH_CANONICAL_ISSUES := $(BUILD_DIR)/$(S3_BUCKET_CANONICAL)/$(CANONICAL_PATH_SEGMENT)/issues
  $(call log.debug, LOCAL_PATH_CANONICAL_ISSUES)

# VARIABLE: LOCAL_PATH_CANONICAL_ISSUES
# The corresponding local path for canonical newspaper issues files.
LOCAL_PATH_CANONICAL_ISSUES := $(BUILD_DIR)/$(S3_BUCKET_CANONICAL)/$(CANONICAL_PATH_SEGMENT)/issues
  $(call log.debug, LOCAL_PATH_CANONICAL_ISSUES)

# VARIABLE: LOCAL_CANONICAL_PAGES_STAMP_FILE_LIST
# Stores all locally available canonical pages stamp files for dependency tracking
# Note: Canonical pages use yearly issue-level stamps with hard-coded .stamp suffix (e.g., AATA-1846.stamp)
LOCAL_CANONICAL_PAGES_STAMP_FILE_LIST := \
    $(shell ls -r $(LOCAL_PATH_CANONICAL_PAGES)/*.stamp 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_CANONICAL_PAGES_STAMP_FILE_LIST)

# VARIABLE: LOCAL_CANONICAL_AUDIOS_STAMP_FILE_LIST
# Stores all locally available canonical audio stamp files for dependency tracking
# Note: Canonical audios use yearly issue-level stamps with hard-coded .stamp suffix (e.g., ana_media-1996.stamp)
LOCAL_CANONICAL_AUDIOS_STAMP_FILE_LIST := \
    $(shell ls -r $(LOCAL_PATH_CANONICAL_AUDIOS)/*.stamp 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_CANONICAL_AUDIOS_STAMP_FILE_LIST)

# VARIABLE: LOCAL_CANONICAL_INPUT_STAMP_FILE_LIST
# Stores the selected canonical input stamps. In auto mode, both canonical
# layouts are considered; normally only one side has stamps for a given source.
ifeq ($(CANONICAL_INPUT_KIND),audios)
LOCAL_CANONICAL_INPUT_STAMP_FILE_LIST := $(LOCAL_CANONICAL_AUDIOS_STAMP_FILE_LIST)
else ifeq ($(CANONICAL_INPUT_KIND),pages)
LOCAL_CANONICAL_INPUT_STAMP_FILE_LIST := $(LOCAL_CANONICAL_PAGES_STAMP_FILE_LIST)
else
LOCAL_CANONICAL_INPUT_STAMP_FILE_LIST := $(LOCAL_CANONICAL_PAGES_STAMP_FILE_LIST) $(LOCAL_CANONICAL_AUDIOS_STAMP_FILE_LIST)
endif
  $(call log.debug, LOCAL_CANONICAL_INPUT_STAMP_FILE_LIST)

$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_canonical.mk)
