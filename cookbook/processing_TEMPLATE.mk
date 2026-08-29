$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_TEMPLATE.mk)
###############################################################################
# TEMPLATE TARGETS
# Targets for processing newspaper content with OCR quality assessment
###############################################################################

# DOUBLE-COLON-TARGET: sync-output
# Synchronizes TEMPLATE processing output data
sync-output :: sync-TEMPLATE

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes TEMPLATE processing input data
# @TODO: This needs to be updated to TEMPLATE processing
sync-input :: sync-rebuilt 

# DOUBLE-COLON-TARGET: TEMPLATE-target
processing-target :: TEMPLATE-target


# VARIABLE: LOCAL_REBUILT_STAMP_FILES
# Stores all locally available rebuilt stamp files for dependency tracking
# Rebuilt stamps match S3 file names exactly (no suffix)
LOCAL_REBUILT_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


# FUNCTION: LocalRebuiltToTEMPLATEFile
# Converts a local rebuilt stamp file name to a local TEMPLATE file name
# Rebuilt stamps match S3 file names exactly (no suffix)
define LocalRebuiltToTEMPLATEFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_TEMPLATE)/%.jsonl.bz2)
endef


# VARIABLE: LOCAL_TEMPLATE_FILES
# Stores the list of OCR quality assessment files based on rebuilt stamp files
LOCAL_TEMPLATE_FILES := \
    $(call LocalRebuiltToTEMPLATEFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_TEMPLATE_FILES)

# TARGET: TEMPLATE-target
#: Processes newspaper content with OCR quality assessment
#
# Just uses the local data that is there, does not enforce synchronization
TEMPLATE-target: $(LOCAL_TEMPLATE_FILES)

.PHONY: TEMPLATE-target

# FILE-RULE: $(LOCAL_PATH_TEMPLATE)/%.jsonl.bz2
#: Rule to process a single newspaper
#: Rebuilt stamps match S3 file names exactly (no suffix to strip)
$(LOCAL_PATH_TEMPLATE)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
    python3 lib/cli_TEMPLATE.py \
      --input $(call LocalToS3,$<) \
      --output $@ \
      --log-file $@.log.gz \
    && \
    python3 -m impresso_cookbook.local_to_s3 \
      $@        $(call LocalToS3,$@) \
      $@.log.gz $(call LocalToS3,$@).log.gz \
    || { rm -vf $@ ; exit 1 ; }


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_TEMPLATE.mk)
