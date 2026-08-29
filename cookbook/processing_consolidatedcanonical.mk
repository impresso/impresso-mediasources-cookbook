$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_consolidatedcanonical.mk)
###############################################################################
# consolidatedcanonical TARGETS
# Targets for processing canonical content with language identification
# and OCR quality assessment consolidation
#
# This module consolidates canonical issue data with langident/OCRQA
# enrichments to produce consolidated canonical format with all
# consolidated_* properties as defined in issue.schema.json
#
# Input Requirements:
# - Canonical issues from s3://112-canonical-final/ (JSONL format)
# - Canonical pages or audios from s3://112-canonical-final/ (JSONL format)
# - Langident/OCRQA enrichments from s3://115-canonical-processed-final/
#
# Processing:
# - Issues: Renames lg → lg_original, adds consolidated_* fields
# - Records: Copies pages/audios from canonical to consolidated bucket
# - Sets consolidated=true and updates timestamps
#
# Output:
# - Consolidated canonical issues (JSONL format)
# - Consolidated canonical pages/audios (JSONL format, copied)
###############################################################################

# USER-VARIABLE: CONSOLIDATEDCANONICAL_VALIDATE_OPTION
# Option to enable schema validation of the consolidated canonical output
#
# Set to --validate to enable JSON schema validation against issue.schema.json
# Set to empty value or $(EMPTY) to disable validation
CONSOLIDATEDCANONICAL_VALIDATE_OPTION ?= --validate
  $(call log.debug, CONSOLIDATEDCANONICAL_VALIDATE_OPTION)

# USER-VARIABLE: CONSOLIDATEDCANONICAL_UPLOAD_IF_NEWER_OPTION
# Option to control S3 upload behavior based on timestamps.
#
# Set to --upload-if-newer to upload only if local timestamp is newer than S3,
# or leave empty to skip upload (file metadata only will be updated).
# Note: Without --force-write, files are not uploaded to S3 by default.
# This is useful when you want to update S3 when local files have changed without
# forcing overwrite of content-wise unchanged files.
# CONSOLIDATEDCANONICAL_UPLOAD_IF_NEWER_OPTION ?= --upload-if-newer
CONSOLIDATEDCANONICAL_UPLOAD_IF_NEWER_OPTION ?=
  $(call log.debug, CONSOLIDATEDCANONICAL_UPLOAD_IF_NEWER_OPTION)

# USER-VARIABLE: CONSOLIDATEDCANONICAL_WIP_ENABLED
# Option to enable S3 work-in-progress locks for issue consolidation.
#
# Set to 1 to check S3 immediately before expensive processing. The check skips
# processing when the output already exists on S3 or another worker owns a fresh
# .wip lock. This complements local sync stamps for multimachine processing.
CONSOLIDATEDCANONICAL_WIP_ENABLED ?= 1
  $(call log.debug, CONSOLIDATEDCANONICAL_WIP_ENABLED)

# USER-VARIABLE: CONSOLIDATEDCANONICAL_WIP_MAX_AGE
# Maximum age in hours before a consolidatedcanonical WIP file is treated as stale.
CONSOLIDATEDCANONICAL_WIP_MAX_AGE ?= 24
  $(call log.debug, CONSOLIDATEDCANONICAL_WIP_MAX_AGE)

# USER-VARIABLE: CONSOLIDATEDCANONICAL_FORCE_OVERWRITE_OPTION
# Option to force S3 overwrite of existing consolidatedcanonical outputs.
#
# Set to --force-overwrite to process and upload even when S3 output exists.
CONSOLIDATEDCANONICAL_FORCE_OVERWRITE_OPTION ?=
  $(call log.debug, CONSOLIDATEDCANONICAL_FORCE_OVERWRITE_OPTION)

# VARIABLE: CONSOLIDATEDCANONICAL_WIP_FORCE_OPTION
# Internal flag to force WIP acquisition when force-overwrite is enabled.
CONSOLIDATEDCANONICAL_WIP_FORCE_OPTION := $(if $(CONSOLIDATEDCANONICAL_FORCE_OVERWRITE_OPTION),--force,)
  $(call log.debug, CONSOLIDATEDCANONICAL_WIP_FORCE_OPTION)

# DOUBLE-COLON-TARGET: sync-output
# Synchronizes consolidatedcanonical processing output data from S3 to local
# Downloads existing consolidated canonical files for resume/inspection
sync-output :: sync-consolidatedcanonical

# DOUBLE-COLON-TARGET: clean-sync-output
clean-sync-output:: clean-sync-consolidatedcanonical

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes canonical and langident enrichment input data for consolidation
sync-input :: sync-consolidatedcanonical-input

# DOUBLE-COLON-TARGET: processing-target
# Main processing target for consolidatedcanonical
processing-target :: consolidatedcanonical-target

# VARIABLE: LOCAL_CANONICAL_RECORD_STAMP_FILES
# Stores selected locally available canonical record stamp files for dependency tracking.
# Values come from paths_canonical.mk and may include pages, audios, or both in auto mode.
LOCAL_CANONICAL_RECORD_STAMP_FILES := $(LOCAL_CANONICAL_INPUT_STAMP_FILE_LIST)
  $(call log.debug, LOCAL_CANONICAL_RECORD_STAMP_FILES)

# VARIABLE: LOCAL_LANGIDENT_ENRICHMENT_STAMP_FILES
# Stores all locally available langident enrichment stamp files for dependency tracking
# Looks for .jsonl.bz2 files (actual enrichment stamp files from langident sync)
LOCAL_LANGIDENT_ENRICHMENT_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_LANGIDENT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_LANGIDENT_ENRICHMENT_STAMP_FILES)

# FUNCTION: LocalCanonicalRecordToConsolidatedIssueFile
# Converts a local canonical page/audio record stamp file to the corresponding consolidated issues file
# Input: build.d/112-canonical-final/CANONICAL_PATH_SEGMENT/pages-or-audios/NEWSPAPER-YEAR.stamp
# Output: $(LOCAL_PATH_CONSOLIDATEDCANONICAL)/issues/NEWSPAPER-YEAR-issues.jsonl.bz2
define LocalCanonicalRecordToConsolidatedIssueFile
$(patsubst $(LOCAL_PATH_CANONICAL_AUDIOS)/%.stamp,$(LOCAL_PATH_CONSOLIDATEDCANONICAL)/issues/%-issues.jsonl.bz2,$(patsubst $(LOCAL_PATH_CANONICAL_PAGES)/%.stamp,$(LOCAL_PATH_CONSOLIDATEDCANONICAL)/issues/%-issues.jsonl.bz2,$(1)))
endef

# FUNCTION: LocalCanonicalRecordToEnrichmentFile
# Converts a local canonical page/audio stamp file to the corresponding enrichment file
# Input: build.d/112-canonical-final/CANONICAL_PATH_SEGMENT/pages-or-audios/NEWSPAPER-YEAR.stamp
# Output: build.d/115-canonical-processed-final/langident/RUN_ID/CANONICAL_PATH_SEGMENT/NEWSPAPER-YEAR.jsonl.bz2
# Note: Canonical stamps have hard-coded .stamp suffix, output is .jsonl.bz2 (the actual enrichment file)
define LocalCanonicalRecordToEnrichmentFile
$(patsubst $(LOCAL_PATH_CANONICAL_AUDIOS)/%.stamp,$(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2,$(patsubst $(LOCAL_PATH_CANONICAL_PAGES)/%.stamp,$(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2,$(1)))
endef

# FUNCTION: LocalCanonicalRecordToConsolidatedRecordStamp
# Converts a local canonical page/audio stamp file to a consolidated record stamp file
# Input: build.d/112-canonical-final/CANONICAL_PATH_SEGMENT/pages-or-audios/NEWSPAPER-YEAR.stamp
# Output: build.d/118-canonical-consolidated-final/VERSION/CANONICAL_PATH_SEGMENT/pages-or-audios/NEWSPAPER-YEAR.stamp
# Note: Both input and output use hard-coded .stamp suffix for tracking sync status
define LocalCanonicalRecordToConsolidatedRecordStamp
$(patsubst $(LOCAL_PATH_CANONICAL_AUDIOS)/%.stamp,$(LOCAL_PATH_CONSOLIDATEDCANONICAL_AUDIOS)/%.stamp,$(patsubst $(LOCAL_PATH_CANONICAL_PAGES)/%.stamp,$(LOCAL_PATH_CONSOLIDATEDCANONICAL_PAGES)/%.stamp,$(1)))
endef

# VARIABLE: LOCAL_CONSOLIDATEDCANONICAL_ISSUE_FILES
# Stores the list of consolidated canonical issues files based on canonical record stamp files
LOCAL_CONSOLIDATEDCANONICAL_ISSUE_FILES := \
    $(call LocalCanonicalRecordToConsolidatedIssueFile,$(LOCAL_CANONICAL_RECORD_STAMP_FILES))
  $(call log.info, LOCAL_CONSOLIDATEDCANONICAL_ISSUE_FILES)

# VARIABLE: LOCAL_CONSOLIDATEDCANONICAL_RECORD_STAMPS
# Stores the list of consolidated record stamp files based on canonical record stamps.
# These track the copy/processing status of pages/audio data.
LOCAL_CONSOLIDATEDCANONICAL_RECORD_STAMPS := \
    $(call LocalCanonicalRecordToConsolidatedRecordStamp,$(LOCAL_CANONICAL_RECORD_STAMP_FILES))
  $(call log.info, LOCAL_CONSOLIDATEDCANONICAL_RECORD_STAMPS)

# TARGET: consolidatedcanonical-target
#: Processes canonical content with consolidated canonical format
#
# Merges canonical issues with langident/OCRQA enrichments and copies records.
# Uses recursive make to ensure input stamp files exist before building file list.
# Depends on:
#   - canonical pages/audio stamp sync files
#   - final langident enrichment sync file
consolidatedcanonical-target: $(LOCAL_CANONICAL_INPUT_SYNC_STAMP_FILES) $(LOCAL_LANGIDENT_SYNC_STAMP_FILE)
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) consolidatedcanonical-files-target

.PHONY: consolidatedcanonical-target

# TARGET: consolidatedcanonical-files-target
#: Internal target that builds the actual consolidated files (issues and records)
# Called recursively after sync to ensure stamp files are available
consolidatedcanonical-files-target: $(LOCAL_CONSOLIDATEDCANONICAL_ISSUE_FILES) $(LOCAL_CONSOLIDATEDCANONICAL_RECORD_STAMPS)

.PHONY: consolidatedcanonical-files-target

# RECIPE: ConsolidatedCanonicalIssueRecipe
# Process and upload one consolidated issue file. The S3 WIP preflight is an
# online guard for distributed runs where another machine may have produced the
# output after this worker's local sync.
define ConsolidatedCanonicalIssueRecipe
$(MAKE_SILENCE_RECIPE) \
mkdir -p $(@D) && \
{ set +e ; \
  if [ -n "$(CONSOLIDATEDCANONICAL_WIP_ENABLED)" ] ; then \
    $(PYTHON) -m impresso_cookbook.manage_s3_wip acquire \
      --s3-target $(call LocalToS3,$@,'') \
      --wip-max-age $(CONSOLIDATEDCANONICAL_WIP_MAX_AGE) \
      --log-level $(LOGGING_LEVEL) \
      --local-target $@ \
      --files $@ $@.log.gz \
      $(CONSOLIDATEDCANONICAL_WIP_FORCE_OPTION) ; \
    status=$$? ; \
    case $$status in 0) ;; 2|3) exit 0 ;; *) exit $$status ;; esac ; \
  fi ; \
  $(PYTHON) lib/cli_consolidatedcanonical.py \
    --canonical-input $(S3_PATH_CANONICAL_ISSUES)/$*-issues.jsonl.bz2 \
    --enrichment-input $(S3_PATH_LANGIDENT)/$*.jsonl.bz2 \
    --output $@ \
    --langident-run-id $(LANGIDENT_ENRICHMENT_RUN_ID) \
    $(CONSOLIDATEDCANONICAL_VALIDATE_OPTION) \
    --log-level $(LOGGING_LEVEL) \
    --log-file $@.log.gz ; \
  status=$$? ; \
  if [ $$status -ne 0 ] ; then \
    rm -f $@ ; \
    if [ -n "$(CONSOLIDATEDCANONICAL_WIP_ENABLED)" ] ; then \
      $(PYTHON) -m impresso_cookbook.manage_s3_wip release \
        --s3-target $(call LocalToS3,$@,'') \
        --log-level $(LOGGING_LEVEL) || true ; \
    fi ; \
    exit $$status ; \
  fi ; \
  $(PYTHON) -m impresso_cookbook.local_to_s3 \
    --set-timestamp --log-level $(LOGGING_LEVEL) \
    --keep-timestamp-only \
    $(CONSOLIDATEDCANONICAL_UPLOAD_IF_NEWER_OPTION) \
    $(CONSOLIDATEDCANONICAL_FORCE_OVERWRITE_OPTION) \
    $@        $(call LocalToS3,$@,'') \
    $@.log.gz $(call LocalToS3,$@,'').log.gz ; \
  status=$$? ; \
  if [ -n "$(CONSOLIDATEDCANONICAL_WIP_ENABLED)" ] ; then \
    $(PYTHON) -m impresso_cookbook.manage_s3_wip release \
      --s3-target $(call LocalToS3,$@,'') \
      --log-level $(LOGGING_LEVEL) || true ; \
  fi ; \
  if [ $$status -ne 0 ] ; then \
    rm -f $@ ; \
    exit $$status ; \
  fi ; \
}
endef

# FILE-RULE: $(LOCAL_PATH_CONSOLIDATEDCANONICAL)/issues/%-issues.jsonl.bz2
#: Rule to process a single year from canonical page stamps
#
# Pattern matches consolidated canonical output files for the current newspaper.
# 
# Dependencies:
# - Canonical pages stamp (.stamp file from sync - used as proxy for issue data availability)
# - Langident enrichment file (.jsonl.bz2 file from langident processing)
#
# Processing:
# - Reads canonical issues from S3
# - Reads langident enrichments from S3  
# - Merges data with strict matching
# - Writes consolidated canonical output
# - Uploads to S3
$(LOCAL_PATH_CONSOLIDATEDCANONICAL)/issues/%-issues.jsonl.bz2: \
    $(LOCAL_PATH_CANONICAL_PAGES)/%.stamp \
    $(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2 \
    | $(LOCAL_LANGIDENT_SYNC_STAMP_FILE)
	$(ConsolidatedCanonicalIssueRecipe)

# FILE-RULE: $(LOCAL_PATH_CONSOLIDATEDCANONICAL)/issues/%-issues.jsonl.bz2
#: Rule to process a single year from canonical audio stamps
$(LOCAL_PATH_CONSOLIDATEDCANONICAL)/issues/%-issues.jsonl.bz2: \
    $(LOCAL_PATH_CANONICAL_AUDIOS)/%.stamp \
    $(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2 \
    | $(LOCAL_LANGIDENT_SYNC_STAMP_FILE)
	$(ConsolidatedCanonicalIssueRecipe)

# FILE-RULE: $(LOCAL_PATH_CONSOLIDATEDCANONICAL_PAGES)/%.stamp
#: Rule to process/copy pages data from canonical to consolidated bucket
#
# Pattern matches consolidated canonical pages stamps for the current newspaper.
# Currently performs a direct copy from canonical S3 to consolidated S3.
# Future versions may integrate additional data (e.g., ReOCR results).
# 
# Dependencies:
# - Canonical pages stamp (.stamp file from sync)
#
# Processing:
# - Copies all pages files for the year from canonical S3 to consolidated S3
# - Creates a stamp file to track completion
# - Preserves directory structure and file organization
$(LOCAL_PATH_CONSOLIDATEDCANONICAL_PAGES)/%.stamp: \
    $(LOCAL_PATH_CANONICAL_PAGES)/%.stamp
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	AWS_CONFIG_FILE=.aws/config AWS_SHARED_CREDENTIALS_FILE=.aws/credentials aws s3 cp \
		--recursive \
		--endpoint-url $(SE_HOST_URL) \
		$(S3_PATH_CANONICAL_PAGES)/$*/ \
		$(S3_PATH_CONSOLIDATEDCANONICAL_PAGES)/$*/ \
	&& touch $@

# FILE-RULE: $(LOCAL_PATH_CONSOLIDATEDCANONICAL_AUDIOS)/%.stamp
#: Rule to copy audio data from canonical to consolidated bucket
#
# Pattern matches consolidated canonical audio stamps for the current source.
# Dependencies:
# - Canonical audios stamp (.stamp file from sync)
$(LOCAL_PATH_CONSOLIDATEDCANONICAL_AUDIOS)/%.stamp: \
    $(LOCAL_PATH_CANONICAL_AUDIOS)/%.stamp
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	AWS_CONFIG_FILE=.aws/config AWS_SHARED_CREDENTIALS_FILE=.aws/credentials aws s3 cp \
		--recursive \
		--endpoint-url $(SE_HOST_URL) \
		$(S3_PATH_CANONICAL_AUDIOS)/$*/ \
		$(S3_PATH_CONSOLIDATEDCANONICAL_AUDIOS)/$*/ \
	&& touch $@

$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_consolidatedcanonical.mk)
