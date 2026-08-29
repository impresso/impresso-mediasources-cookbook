$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_mediasources.mk)
###############################################################################
# mediasources TARGETS
# Targets for processing newspaper content with media-source NER
###############################################################################


sync-output :: sync-mediasources

sync-input :: sync-rebuilt

processing-target :: mediasources-target


LOCAL_REBUILT_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


define LocalRebuiltToMediasourcesFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_MEDIASOURCES)/%.jsonl.bz2)
endef


LOCAL_MEDIASOURCES_FILES := \
    $(call LocalRebuiltToMediasourcesFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_MEDIASOURCES_FILES)


#: Processes newspaper content with media-source NER
mediasources-target: $(LOCAL_MEDIASOURCES_FILES)

.PHONY: mediasources-target


$(LOCAL_PATH_MEDIASOURCES)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
    python3 lib/cli_mediasources.py \
      --input $(call LocalToS3,$<) \
      --output $@ \
      --log-file $@.log.gz \
      --log-level $(LOGGING_LEVEL) \
      --hf-model $(HF_MODEL_MEDIASOURCES) \
      --revision $(HF_MODEL_REVISION_MEDIASOURCES) \
      --batch-size $(BATCH_SIZE_MEDIASOURCES) \
      --outer-batch-size $(OUTER_BATCH_SIZE_MEDIASOURCES) \
    && \
    python3 -m impresso_cookbook.local_to_s3 \
      $@        $(call LocalToS3,$@) \
      $@.log.gz $(call LocalToS3,$@).log.gz \
    || { rm -vf $@ ; exit 1 ; }


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_mediasources.mk)

