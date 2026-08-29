$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_topics.mk)

###############################################################################
# Processing Topics
# Mapping local processed linguistic data to topics and handling S3 updates
#
# This Makefile defines rules for transforming linguistic processing outputs
# into topic-based representations. It also includes settings for managing
# interactions with S3 storage, including dry-run options, retention policies,
# and conditional execution based on S3 file existence.
###############################################################################

# DOUBLE-COLON-TARGET: topics-target
processing-target :: topics-target

# FUNCTION: LocalLingprocToTopicsFile
# Maps local processed linguistic data to corresponding topic files
#
define LocalLingprocToTopicsFile
$(1:$(LOCAL_PATH_LINGPROC)/%.jsonl.bz2=$(LOCAL_PATH_TOPICS)/%.jsonl.bz2)
endef


# USER-VARIABLE: TOPICS_LOGGING_LEVEL
# Option to specify logging level for topic processing.
TOPICS_LOGGING_LEVEL ?= $(LOGGING_LEVEL)
  $(call log.debug, TOPICS_LOGGING_LEVEL)

# USER-VARIABLE: TOPICS_MIN_P
# Minimum topic probability threshold emitted by the inferencer.
TOPICS_MIN_P ?= 0.05
  $(call log.debug, TOPICS_MIN_P)

# USER-VARIABLE: TOPICS_LANGUAGES
# Space-separated language codes passed to the inferencer.
TOPICS_LANGUAGES ?= de fr lb
  $(call log.debug, TOPICS_LANGUAGES)

# USER-VARIABLE: TOPICS_MALLET_HOME
# Optional MALLET runtime directory. Required when the selected model configs declare
# a runtime that is not vendored in this repository, such as mallet-2.1.0.
TOPICS_MALLET_HOME ?=
  $(call log.debug, TOPICS_MALLET_HOME)

# USER-VARIABLE: TOPICS_DE_CONFIG
# German topic-model config path.
TOPICS_DE_CONFIG ?= models/tm/tm-de-all-v2.0.config.json
  $(call log.debug, TOPICS_DE_CONFIG)

# USER-VARIABLE: TOPICS_FR_CONFIG
# French topic-model config path.
TOPICS_FR_CONFIG ?= models/tm/tm-fr-all-v2.0.config.json
  $(call log.debug, TOPICS_FR_CONFIG)

# USER-VARIABLE: TOPICS_LB_CONFIG
# Luxembourgish topic-model config path.
TOPICS_LB_CONFIG ?= models/tm/tm-lb-all-v2.1.config.json
  $(call log.debug, TOPICS_LB_CONFIG)

# USER-VARIABLE: TOPICS_EN_CONFIG
# English topic-model config path.
TOPICS_EN_CONFIG ?= models/tm/tm-en-all-v3.0.config.json
  $(call log.debug, TOPICS_EN_CONFIG)

# USER-VARIABLE: TOPICS_WIP_ENABLED
# Option to enable S3 WIP locks for topic processing.
TOPICS_WIP_ENABLED ?= 1
  $(call log.debug, TOPICS_WIP_ENABLED)

# USER-VARIABLE: TOPICS_WIP_MAX_AGE
# Maximum age in hours before a topics WIP file is treated as stale.
TOPICS_WIP_MAX_AGE ?= 1
  $(call log.debug, TOPICS_WIP_MAX_AGE)

# USER-VARIABLE: TOPICS_UPLOAD_IF_NEWER_OPTION
# Upload outputs only when the local timestamp is newer than S3.
TOPICS_UPLOAD_IF_NEWER_OPTION ?=
  $(call log.debug, TOPICS_UPLOAD_IF_NEWER_OPTION)

# USER-VARIABLE: TOPICS_DRY_RUN_OPTION
# Prevent any S3-side action for topics processing while still generating local output.
TOPICS_DRY_RUN_OPTION ?= $(PROCESSING_S3_OUTPUT_DRY_RUN)
  $(call log.debug, TOPICS_DRY_RUN_OPTION)

# USER-VARIABLE: TOPICS_SKIP_IF_OUTPUT_EXISTS_OPTION
# Skip processing when the topics output already exists on S3.
TOPICS_SKIP_IF_OUTPUT_EXISTS_OPTION ?= $(PROCESSING_QUIT_IF_S3_OUTPUT_EXISTS_OPTION)
  $(call log.debug, TOPICS_SKIP_IF_OUTPUT_EXISTS_OPTION)

# USER-VARIABLE: TOPICS_KEEP_TIMESTAMP_ONLY_OPTION
# Keep only local timestamps after a successful upload.
TOPICS_KEEP_TIMESTAMP_ONLY_OPTION ?= $(PROCESSING_KEEP_TIMESTAMP_ONLY_OPTION)
  $(call log.debug, TOPICS_KEEP_TIMESTAMP_ONLY_OPTION)

# USER-VARIABLE: TOPICS_FORCE_OVERWRITE_OPTION
# Force overwrite of existing topics outputs on S3.
TOPICS_FORCE_OVERWRITE_OPTION ?=
  $(call log.debug, TOPICS_FORCE_OVERWRITE_OPTION)

# USER-VARIABLE: TOPICS_FORCE_UPLOAD_OPTION
# Backward-compatible alias for TOPICS_FORCE_OVERWRITE_OPTION.
TOPICS_FORCE_UPLOAD_OPTION ?= $(TOPICS_FORCE_OVERWRITE_OPTION)
  $(call log.debug, TOPICS_FORCE_UPLOAD_OPTION)

TOPICS_EFFECTIVE_FORCE_OVERWRITE_OPTION := $(or $(TOPICS_FORCE_OVERWRITE_OPTION),$(TOPICS_FORCE_UPLOAD_OPTION))
  $(call log.debug, TOPICS_EFFECTIVE_FORCE_OVERWRITE_OPTION)

TOPICS_WIP_FORCE_OPTION := $(if $(TOPICS_EFFECTIVE_FORCE_OVERWRITE_OPTION),--force,)
  $(call log.debug, TOPICS_WIP_FORCE_OPTION)


# VARIABLE: LOCAL_LINGPROC_FILES
# List of all locally available linguistic processing output files.
# Used for dependency tracking of the build process. Errors are discarded
# as files or directories may not exist initially.
LOCAL_LINGPROC_FILES := \
    $(shell ls -r $(LOCAL_PATH_LINGPROC)/*.jsonl.bz2 2> /dev/null \
      | $(if $(NEWSPAPER_YEAR_SORTING),$(NEWSPAPER_YEAR_SORTING),cat))

$(call log.debug, LOCAL_LINGPROC_FILES)


# VARIABLE: LOCAL_TOPICS_FILES
# List of all locally processed topic files corresponding to linguistic outputs.
LOCAL_TOPICS_FILES := \
    $(call LocalLingprocToTopicsFile,$(LOCAL_LINGPROC_FILES))

$(call log.debug, LOCAL_TOPICS_FILES)


# TARGET: topics-target
#: Generates topic files from linguistic processing outputs.
topics-target: $(LOCAL_TOPICS_FILES)

help-processing::
	@echo "TOPIC PROCESSING:"
	@echo "  topics-target    # Generate topic files from linguistic processing outputs"
	@echo ""
	@echo "TOPICS VARIABLES:"
	@echo "  TOPICS_LOGGING_LEVEL=$(TOPICS_LOGGING_LEVEL)"
	@echo "  TOPICS_MIN_P=$(TOPICS_MIN_P)"
	@echo "  TOPICS_LANGUAGES=$(TOPICS_LANGUAGES)"
	@echo "  TOPICS_WIP_ENABLED=$(TOPICS_WIP_ENABLED)"
	@echo "  TOPICS_WIP_MAX_AGE=$(TOPICS_WIP_MAX_AGE)"
	@echo "  TOPICS_UPLOAD_IF_NEWER_OPTION=$(TOPICS_UPLOAD_IF_NEWER_OPTION)"

# FILE-RULE: Process topics from linguistic processing output
#: Converts linguistic output into topic-based JSONL files.
$(LOCAL_PATH_TOPICS)/%.jsonl.bz2: $(LOCAL_PATH_LINGPROC)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	{ set +e ; \
	  if [ -z "$(TOPICS_DRY_RUN_OPTION)" ] ; then \
	    if [ -n "$(TOPICS_WIP_ENABLED)" ] ; then \
	      python3 -m impresso_cookbook.manage_s3_wip acquire \
	        --s3-target $(call LocalToS3,$@) \
	        --wip-max-age $(TOPICS_WIP_MAX_AGE) \
	        --log-level $(TOPICS_LOGGING_LEVEL) \
	        --local-target $@ \
	        --files $@ $@.log.gz \
	        $(TOPICS_WIP_FORCE_OPTION) ; \
	      status=$$? ; \
	      case $$status in 0) ;; 2|3) exit 0 ;; *) exit $$status ;; esac ; \
	    elif [ -n "$(TOPICS_SKIP_IF_OUTPUT_EXISTS_OPTION)" ] && [ -z "$(TOPICS_EFFECTIVE_FORCE_OVERWRITE_OPTION)" ] ; then \
	      python3 -m impresso_cookbook.local_to_s3 \
	        --s3-file-exists $(call LocalToS3,$@) \
	        --log-level $(TOPICS_LOGGING_LEVEL) ; \
	      status=$$? ; \
	      case $$status in 0) exit 0 ;; 1) ;; *) exit $$status ;; esac ; \
	    fi ; \
	  fi ; \
		  $(if $(TOPICS_MALLET_HOME),MALLET_HOME=$(TOPICS_MALLET_HOME),) \
		  python -m lib.mallet_topic_inferencer \
		    --input $(call LocalToS3,$<) \
		    --input-format impresso \
		    --output $@ \
		    --output-format jsonl \
		    --min-p $(TOPICS_MIN_P) \
		    --languages $(TOPICS_LANGUAGES) \
		    --de_config $(TOPICS_DE_CONFIG) \
		    --fr_config $(TOPICS_FR_CONFIG) \
		    --en_config $(TOPICS_EN_CONFIG) \
		    --lb_config $(TOPICS_LB_CONFIG) \
		    --git-version $(GIT_VERSION) \
		    --lingproc-run_id $(RUN_ID_LINGPROC) \
		    --impresso-model-id $(MODEL_ID_TOPICS) \
	    --inferencer-random-seed $(MALLET_RANDOM_SEED) \
	    --log-level $(TOPICS_LOGGING_LEVEL) \
	    --log-file $@.log.gz ; \
	  status=$$? ; \
	  if [ $$status -ne 0 ] ; then \
	    rm -f $@ ; \
	    if [ -z "$(TOPICS_DRY_RUN_OPTION)" ] && [ -n "$(TOPICS_WIP_ENABLED)" ] ; then \
	      python3 -m impresso_cookbook.manage_s3_wip release \
	        --s3-target $(call LocalToS3,$@) \
	        --log-level $(TOPICS_LOGGING_LEVEL) || true ; \
	    fi ; \
	    exit $$status ; \
	  fi ; \
	  if [ -z "$(TOPICS_DRY_RUN_OPTION)" ] ; then \
	    python3 -m impresso_cookbook.local_to_s3 \
	      --set-timestamp $(TOPICS_UPLOAD_IF_NEWER_OPTION) \
	      $(TOPICS_EFFECTIVE_FORCE_OVERWRITE_OPTION) \
	      $(TOPICS_KEEP_TIMESTAMP_ONLY_OPTION) \
	      --log-level $(TOPICS_LOGGING_LEVEL) \
	      $@ $(call LocalToS3,$@) \
	      $@.log.gz $(call LocalToS3,$@).log.gz ; \
	    status=$$? ; \
	    if [ -n "$(TOPICS_WIP_ENABLED)" ] ; then \
	      python3 -m impresso_cookbook.manage_s3_wip release \
	        --s3-target $(call LocalToS3,$@) \
	        --log-level $(TOPICS_LOGGING_LEVEL) || true ; \
	    fi ; \
	    if [ $$status -ne 0 ] ; then \
	      rm -f $@ ; \
	      exit $$status ; \
	    fi ; \
	  fi ; \
	}

$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_topics.mk)
