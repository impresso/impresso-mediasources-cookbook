$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_content_item_classification.mk)
###############################################################################
# content_item_classification TARGETS
# Targets for processing newspaper content with OCR quality assessment
###############################################################################

# DOUBLE-COLON-TARGET: sync-output
# Synchronizes content_item_classification processing output data
sync-output :: sync-content_item_classification

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes content_item_classification processing input data
# @TODO: This needs to be updated to content_item_classification processing
sync-input :: sync-rebuilt 

# DOUBLE-COLON-TARGET: content_item_classification-target
processing-target :: content_item_classification-target


# VARIABLE: LOCAL_REBUILT_STAMP_FILES
# Stores all locally available rebuilt stamp files for dependency tracking
# Rebuilt stamps match S3 file names exactly (no suffix)
LOCAL_REBUILT_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


# FUNCTION: LocalRebuiltTocontent_item_classificationFile
# Converts a local rebuilt stamp file name to a local content_item_classification file name
# Rebuilt stamps match S3 file names exactly (no suffix)
define LocalRebuiltTocontent_item_classificationFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_content_item_classification)/%.jsonl.bz2)
endef


# VARIABLE: LOCAL_content_item_classification_FILES
# Stores the list of OCR quality assessment files based on rebuilt stamp files
LOCAL_content_item_classification_FILES := \
    $(call LocalRebuiltTocontent_item_classificationFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_content_item_classification_FILES)

# TARGET: content_item_classification-target
#: Processes newspaper content with OCR quality assessment
#
# Just uses the local data that is there, does not enforce synchronization
content_item_classification-target: $(LOCAL_content_item_classification_FILES)

.PHONY: content_item_classification-target

# FILE-RULE: $(LOCAL_PATH_content_item_classification)/%.jsonl.bz2
#: Rule to process a single newspaper
#: Rebuilt stamps match S3 file names exactly (no suffix to strip)
$(LOCAL_PATH_content_item_classification)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
    $(PYTHON) lib/cli_content_item_classification.py \
      --input $(call LocalToS3,$<) \
      --output $@ \
      --log-file $@.log.gz \
      --model-id $(HF_MODEL_CONTENT_ITEM_CLASSIFICATION) \
    && \
    $(PYTHON) -m impresso_cookbook.local_to_s3 \
      $@        $(call LocalToS3,$@) \
      $@.log.gz $(call LocalToS3,$@).log.gz \
    || { rm -vf $@ ; exit 1 ; }


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_content_item_classification.mk)
