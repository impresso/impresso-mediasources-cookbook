$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_consolidatedcanonical.mk)
###############################################################################
# consolidatedcanonical Configuration
# Defines S3 and local paths for consolidatedcanonical processing
#
# This module consolidates canonical newspaper data with language identification
# and OCR quality assessment enrichments to produce consolidated canonical format.
#
# PATH STRUCTURE:
# ==============
# Consolidated canonical mirrors the canonical structure with a VERSION prefix:
#
# Canonical:    s3://112-canonical-final/CANONICAL_PATH_SEGMENT/issues/
# Consolidated: s3://118-canonical-consolidated-final/VERSION/CANONICAL_PATH_SEGMENT/issues/
#
# Where CANONICAL_PATH_SEGMENT can be:
#   - PROVIDER/NEWSPAPER (e.g., BL/WTCH) when NEWSPAPER_HAS_PROVIDER=1
#   - NEWSPAPER (e.g., WTCH) when NEWSPAPER_HAS_PROVIDER=0
#
# Input sources:
# - Canonical issues: s3://112-canonical-final/CANONICAL_PATH_SEGMENT/issues/
# - Langident enrichments: s3://115-canonical-processed-final/langident/RUN_ID/CANONICAL_PATH_SEGMENT/
#
# Output:
# - Consolidated issues: s3://118-canonical-consolidated-final/VERSION/CANONICAL_PATH_SEGMENT/issues/
###############################################################################


# USER-VARIABLE: S3_BUCKET_LANGIDENT_ENRICHMENT
# The bucket containing langident and OCRQA enrichment data
#
# Defines the S3 bucket where language identification and OCR quality
# assessment results are stored.
# Example: 113-canonical-processed-sandbox
S3_BUCKET_LANGIDENT_ENRICHMENT ?= 113-canonical-processed-sandbox
  $(call log.debug, S3_BUCKET_LANGIDENT_ENRICHMENT)


# USER-VARIABLE: S3_BUCKET_CONSOLIDATEDCANONICAL
# The output bucket for consolidatedcanonical processing
#
# Defines the S3 bucket where the consolidated canonical data is stored.
# Structure: s3://<your-bucket-name>/VERSION/PROVIDER/NEWSPAPER/
# Example: 116-canonical-consolidated-sandbox
S3_BUCKET_CONSOLIDATEDCANONICAL ?= 116-canonical-consolidated-sandbox
  $(call log.debug, S3_BUCKET_CONSOLIDATEDCANONICAL)


# USER-VARIABLE: PROCESS_LABEL_CONSOLIDATEDCANONICAL
# Label for the processing task
#
# A general label for identifying consolidatedcanonical processing tasks.
PROCESS_LABEL_CONSOLIDATEDCANONICAL ?= consolidatedcanonical
  $(call log.debug, PROCESS_LABEL_CONSOLIDATEDCANONICAL)


# USER-VARIABLE: PROCESS_SUBTYPE_LABEL_CONSOLIDATEDCANONICAL
# Subtype label for processing
#
# Optional additional label for subtypes of processing.
PROCESS_SUBTYPE_LABEL_CONSOLIDATEDCANONICAL ?=
  $(call log.debug, PROCESS_SUBTYPE_LABEL_CONSOLIDATEDCANONICAL)


# USER-VARIABLE: LANGIDENT_ENRICHMENT_PROCESS_LABEL
# Label for the langident enrichment process
#
# Identifies the langident enrichment data to use for consolidation.
LANGIDENT_ENRICHMENT_PROCESS_LABEL ?= langident
  $(call log.debug, LANGIDENT_ENRICHMENT_PROCESS_LABEL)


# USER-VARIABLE: LANGIDENT_ENRICHMENT_RUN_ID
# Run ID for the langident enrichment data
#
# Specifies which langident run results to use for consolidation.
# Example: langident-lid-ensemble_multilingual_v2-0-2
LANGIDENT_ENRICHMENT_RUN_ID ?= langident-lid-ensemble_multilingual_v2-0-2
  $(call log.debug, LANGIDENT_ENRICHMENT_RUN_ID)


# USER-VARIABLE: TASK_CONSOLIDATEDCANONICAL
# The specific consolidatedcanonical processing task
#
# Defines the specific consolidatedcanonical processing task.
TASK_CONSOLIDATEDCANONICAL ?= consolidation
  $(call log.debug, TASK_CONSOLIDATEDCANONICAL)


# USER-VARIABLE: MODEL_ID_CONSOLIDATEDCANONICAL
# The model identifier
#
# Specifies the model used for consolidatedcanonical processing.
MODEL_ID_CONSOLIDATEDCANONICAL ?= merger
  $(call log.debug, MODEL_ID_CONSOLIDATEDCANONICAL)


# USER-VARIABLE: RUN_VERSION_CONSOLIDATEDCANONICAL
# The version of the processing run
#
# Indicates the version of the current processing run.
# Format: vYYYY-MM-DD_INFO (e.g., v2025-11-23_initial)
RUN_VERSION_CONSOLIDATEDCANONICAL ?= v2025-11-23_initial
  $(call log.debug, RUN_VERSION_CONSOLIDATEDCANONICAL)


# VARIABLE: RUN_ID_CONSOLIDATEDCANONICAL
# Unique identifier for the processing run
#
# Constructs a unique identifier based on the process label, task, model, and version.
RUN_ID_CONSOLIDATEDCANONICAL := $(PROCESS_LABEL_CONSOLIDATEDCANONICAL)-$(TASK_CONSOLIDATEDCANONICAL)-$(MODEL_ID_CONSOLIDATEDCANONICAL)_$(RUN_VERSION_CONSOLIDATEDCANONICAL)
  $(call log.debug, RUN_ID_CONSOLIDATEDCANONICAL)


# VARIABLE: PATH_CONSOLIDATEDCANONICAL
# Path for consolidatedcanonical processing data (base path)
#
# Defines the base path for consolidatedcanonical processing data.
# This mirrors the canonical structure with a VERSION prefix:
# - Canonical:    112-canonical-final/CANONICAL_PATH_SEGMENT/
# - Consolidated: 118-canonical-consolidated-final/VERSION/CANONICAL_PATH_SEGMENT/
PATH_CONSOLIDATEDCANONICAL := $(S3_BUCKET_CONSOLIDATEDCANONICAL)/$(RUN_VERSION_CONSOLIDATEDCANONICAL)/$(CANONICAL_PATH_SEGMENT)
  $(call log.debug, PATH_CONSOLIDATEDCANONICAL)


# VARIABLE: S3_PATH_CONSOLIDATEDCANONICAL_ISSUES
# S3 path for consolidated canonical issues
#
# Mirrors the canonical issues structure with VERSION prefix:
# s3://<your-bucket-name>/VERSION/CANONICAL_PATH_SEGMENT/issues/
S3_PATH_CONSOLIDATEDCANONICAL_ISSUES := s3://$(PATH_CONSOLIDATEDCANONICAL)/issues
  $(call log.debug, S3_PATH_CONSOLIDATEDCANONICAL_ISSUES)


# VARIABLE: S3_PATH_CONSOLIDATEDCANONICAL_PAGES
# S3 path for consolidated canonical pages
#
# Mirrors the canonical pages structure with VERSION prefix:
# s3://<your-bucket-name>/VERSION/CANONICAL_PATH_SEGMENT/pages/
S3_PATH_CONSOLIDATEDCANONICAL_PAGES := s3://$(PATH_CONSOLIDATEDCANONICAL)/pages
  $(call log.debug, S3_PATH_CONSOLIDATEDCANONICAL_PAGES)

# VARIABLE: S3_PATH_CONSOLIDATEDCANONICAL_AUDIOS
# S3 path for consolidated canonical audio records
#
# Mirrors the canonical audios structure with VERSION prefix:
# s3://<your-bucket-name>/VERSION/CANONICAL_PATH_SEGMENT/audios/
S3_PATH_CONSOLIDATEDCANONICAL_AUDIOS := s3://$(PATH_CONSOLIDATEDCANONICAL)/audios
  $(call log.debug, S3_PATH_CONSOLIDATEDCANONICAL_AUDIOS)


# VARIABLE: S3_PATH_CONSOLIDATEDCANONICAL
# S3 path for consolidated canonical output (alias for issues path)
#
# Defines the full S3 path where consolidated canonical data is stored.
# Points to the issues directory by default.
S3_PATH_CONSOLIDATEDCANONICAL := $(S3_PATH_CONSOLIDATEDCANONICAL_ISSUES)
  $(call log.debug, S3_PATH_CONSOLIDATEDCANONICAL)


# VARIABLE: LOCAL_PATH_CONSOLIDATEDCANONICAL
# Local path for storing consolidated canonical issues
#
# Defines the local storage path for consolidatedcanonical processing data within BUILD_DIR.
# Mirrors the S3 structure: BUILD_DIR/<your-bucket-name>/VERSION/CANONICAL_PATH_SEGMENT/
# Note: Does not include /issues suffix - that's part of the file pattern
LOCAL_PATH_CONSOLIDATEDCANONICAL := $(BUILD_DIR)/$(PATH_CONSOLIDATEDCANONICAL)
  $(call log.debug, LOCAL_PATH_CONSOLIDATEDCANONICAL)


# VARIABLE: LOCAL_PATH_CONSOLIDATEDCANONICAL_PAGES
# Local path for storing consolidated canonical pages
#
# Defines the local storage path for consolidated pages within BUILD_DIR.
# Mirrors the S3 structure: BUILD_DIR/<your-bucket-name>/VERSION/CANONICAL_PATH_SEGMENT/pages/
LOCAL_PATH_CONSOLIDATEDCANONICAL_PAGES := $(LOCAL_PATH_CONSOLIDATEDCANONICAL)/pages
  $(call log.debug, LOCAL_PATH_CONSOLIDATEDCANONICAL_PAGES)

# VARIABLE: LOCAL_PATH_CONSOLIDATEDCANONICAL_AUDIOS
# Local path for storing consolidated canonical audio record stamps
#
# Mirrors the S3 structure: BUILD_DIR/<bucket>/VERSION/CANONICAL_PATH_SEGMENT/audios/
LOCAL_PATH_CONSOLIDATEDCANONICAL_AUDIOS := $(LOCAL_PATH_CONSOLIDATEDCANONICAL)/audios
  $(call log.debug, LOCAL_PATH_CONSOLIDATEDCANONICAL_AUDIOS)

# VARIABLE: LOCAL_PATH_CONSOLIDATEDCANONICAL_RECORDS
# Selected consolidated record path for configurations that force one record kind.
ifeq ($(CANONICAL_INPUT_KIND),audios)
LOCAL_PATH_CONSOLIDATEDCANONICAL_RECORDS := $(LOCAL_PATH_CONSOLIDATEDCANONICAL_AUDIOS)
S3_PATH_CONSOLIDATEDCANONICAL_RECORDS := $(S3_PATH_CONSOLIDATEDCANONICAL_AUDIOS)
else ifeq ($(CANONICAL_INPUT_KIND),pages)
LOCAL_PATH_CONSOLIDATEDCANONICAL_RECORDS := $(LOCAL_PATH_CONSOLIDATEDCANONICAL_PAGES)
S3_PATH_CONSOLIDATEDCANONICAL_RECORDS := $(S3_PATH_CONSOLIDATEDCANONICAL_PAGES)
endif
  $(call log.debug, LOCAL_PATH_CONSOLIDATEDCANONICAL_RECORDS)
  $(call log.debug, S3_PATH_CONSOLIDATEDCANONICAL_RECORDS)


# VARIABLE: PATH_LANGIDENT_ENRICHMENT
# Path for langident enrichment data
#
# Defines the path for langident/OCRQA enrichment data.
# Structure: <your-bucket-name>/langident/RUN_ID/PROVIDER/NEWSPAPER/ (with provider)
#        or: <your-bucket-name>/langident/RUN_ID/NEWSPAPER/ (without provider)
# Uses CANONICAL_PATH_SEGMENT from paths_canonical.mk for consistency
PATH_LANGIDENT_ENRICHMENT := $(S3_BUCKET_LANGIDENT_ENRICHMENT)/$(LANGIDENT_ENRICHMENT_PROCESS_LABEL)/$(LANGIDENT_ENRICHMENT_RUN_ID)/$(CANONICAL_PATH_SEGMENT)
  $(call log.debug, PATH_LANGIDENT_ENRICHMENT)


# VARIABLE: S3_PATH_LANGIDENT_ENRICHMENT
# S3 path for langident enrichment data
#
# Defines the full S3 path where langident/OCRQA enrichment data is stored.
S3_PATH_LANGIDENT_ENRICHMENT := s3://$(PATH_LANGIDENT_ENRICHMENT)
  $(call log.debug, S3_PATH_LANGIDENT_ENRICHMENT)


# VARIABLE: LOCAL_PATH_LANGIDENT_ENRICHMENT
# Local path for langident enrichment data
#
# Defines the local storage path for langident/OCRQA enrichment data within BUILD_DIR.
LOCAL_PATH_LANGIDENT_ENRICHMENT := $(BUILD_DIR)/$(PATH_LANGIDENT_ENRICHMENT)
  $(call log.debug, LOCAL_PATH_LANGIDENT_ENRICHMENT)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_consolidatedcanonical.mk)
