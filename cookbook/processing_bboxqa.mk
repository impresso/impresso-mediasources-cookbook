$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_bboxqa.mk)
###############################################################################
# BBOX QUALITY ASSESSMENT TARGETS
# Targets for processing newspaper content with BBOX quality assessment
###############################################################################

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes BBOX quality assessment input data
sync-input :: sync-canonical


# DOUBLE-COLON-TARGET: sync-output
# Synchronizes BBOX quality assessment output data
sync-output :: sync-bboxqa


# DOUBLE-COLON-TARGET: bboxqa-target
processing-target :: bboxqa-target


#BBOXQA_IIIF_GALLICA_V3_OPTION ?= --iiif-gallica-v3
BBOXQA_IIIF_GALLICA_V3_OPTION ?= $(EMPTY)
  $(call log.debug, #BBOXQA_IIIF_GALLICA_V3_OPTION ?= --iiif-gallica-v3)

# VARIABLE: CANONICAL_PAGES_STAMP_FILES
# Stores all canonical stamp files for dependency tracking
# Canonical stamps have hard-coded .stamp suffix for yearly directories
CANONICAL_PAGES_STAMP_FILES := \
    $(shell ls -r $(LOCAL_PATH_CANONICAL_PAGES)/*.stamp 2> /dev/null \
    | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))
  $(call log.debug, CANONICAL_PAGES_STAMP_FILES)

# FUNCTION: CanonicalPagesToBboxqaFile
# Converts a canonical stamp file name to a local BBOX quality assessment file name
# Canonical stamps have hard-coded .stamp suffix
define CanonicalPagesToBboxqaFile
$(1:$(LOCAL_PATH_CANONICAL_PAGES)/%.stamp=$(LOCAL_PATH_BBOXQA)/%.jsonl.bz2)
endef

# VARIABLE: LOCAL_BBOXQA_FILES
# Stores the list of BBOX quality assessment files based on canonical stamp files
LOCAL_BBOXQA_FILES := \
    $(call CanonicalPagesToBboxqaFile,$(CANONICAL_PAGES_STAMP_FILES))

  $(call log.debug, LOCAL_BBOXQA_FILES)

# TARGET: bboxqa-target
#: Processes newspaper content with BBOX quality assessment
#
# Just uses the local data that is there, does not enforce synchronization
bboxqa-target: $(LOCAL_BBOXQA_FILES)

.PHONY: bboxqa-target

# FILE-RULE: $(LOCAL_PATH_BBOXQA)/%.jsonl.bz2
#: Rule to process a single newspaper year file
#: Canonical stamps have hard-coded .stamp suffix
$(LOCAL_PATH_BBOXQA)/%.jsonl.bz2: $(LOCAL_PATH_CANONICAL_PAGES)/%.stamp
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) \
  && \
  python3 lib/bboxqa.py \
      --git_version $(GIT_VERSION) \
      --output $@ \
      --log-file $@.log.gz \
      $(call LocalToS3,$<,.stamp) \
  && \
  python3 -m impresso_cookbook.local_to_s3 \
    $(PROCESSING_KEEP_TIMESTAMP_ONLY_OPTION) \
    --set-timestamp \
    $@        $(call LocalToS3,$@) \
    $@.log.gz $(call LocalToS3,$@).log.gz \
  || { rm -vf $@ ; exit 1 ; }


$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_bboxqa.mk)
