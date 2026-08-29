$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_nel.mk)
###############################################################################
# nel TARGETS
# Targets for processing newspaper content with NEL
###############################################################################

# DOUBLE-COLON-TARGET: sync-output
# Synchronizes nel processing output data
sync-output :: sync-nel

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes nel processing input data
sync-input :: sync-rebuilt

# DOUBLE-COLON-TARGET: nel-target
processing-target :: nel-target


# VARIABLE: LOCAL_REBUILT_STAMP_FILES
# Stores all locally available rebuilt stamp files for dependency tracking
# Rebuilt stamps match S3 file names exactly (no suffix)
 LOCAL_REBUILT_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_REBUILT)/*.jsonl.bz2 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, LOCAL_REBUILT_STAMP_FILES)


# FUNCTION: LocalRebuiltToNelFile
# Converts a local rebuilt stamp file name to a local nel file name
# Rebuilt stamps match S3 file names exactly (no suffix)
define LocalRebuiltToNelFile
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_NEL)/%.jsonl.bz2)
endef


# VARIABLE: LOCAL_NEL_FILES
# Stores the list of NEL files based on rebuilt stamp files
LOCAL_NEL_FILES := \
    $(call LocalRebuiltToNelFile,$(LOCAL_REBUILT_STAMP_FILES))

  $(call log.debug, LOCAL_NEL_FILES)

# TARGET: nel-target
#: Processes newspaper content with NEL
#
# Just uses the local data that is there, does not enforce synchronization
nel-target: $(LOCAL_NEL_FILES)

.PHONY: nel-target

# FILE-RULE: $(LOCAL_PATH_NEL)/%.jsonl.bz2
#: Rule to process a single newspaper
#: Rebuilt stamps match S3 file names exactly (no suffix to strip)
$(LOCAL_PATH_NEL)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
    python3 lib/cli_nel.py \
      --input $(call LocalToS3,$<) \
      --output $@ \
      --log-file $@.log.gz \
      --log-level $(LOGGING_LEVEL) \
    && \
    python3 -m impresso_cookbook.local_to_s3 \
      $@        $(call LocalToS3,$@) \
      $@.log.gz $(call LocalToS3,$@).log.gz \
    || { rm -vf $@ ; exit 1 ; }


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_nel.mk)
