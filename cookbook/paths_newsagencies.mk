$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_newsagencies.mk)
###############################################################################
# newsagencies Configuration
# Defines S3 and local paths for newsagencies processing
###############################################################################


# USER-VARIABLE: S3_BUCKET_newsagencies
# The input bucket for newsagencies processing
#
# Defines the S3 bucket where the processed data is stored.
S3_BUCKET_newsagencies ?= 140-processed-data-sandbox
  $(call log.debug, S3_BUCKET_newsagencies)


# USER-VARIABLE: PROCESS_LABEL_NEWSAGENCIES
# Label for the processing task
#
# A general label for identifying newsagencies processing tasks.
PROCESS_LABEL_NEWSAGENCIES ?= newsagency
  $(call log.debug, PROCESS_LABEL_NEWSAGENCIES)


# USER-VARIABLE: PROCESS_SUBTYPE_LABEL_NEWSAGENCIES
# Subtype label for processing
#
# Optional additional label for subtypes of processing.
PROCESS_SUBTYPE_LABEL_NEWSAGENCIES ?= $(EMPTY)
  $(call log.debug, PROCESS_SUBTYPE_LABEL_NEWSAGENCIES)


# USER-VARIABLE: TASK_NEWSAGENCIES
# The specific newsagencies processing task
#
# Defines the specific newsagencies processing task.
TASK_NEWSAGENCIES ?= nel
  $(call log.debug, TASK_NEWSAGENCIES)


# USER-VARIABLE: MODEL_ID_NEWSAGENCIES
# The model identifier (path-safe label used in S3 paths)
#
# Short identifier combining model name and commit hash, used in output path construction.
# Format: <model-short-name>_<commit-short-hash>  e.g. ner-newsagency-bert-multilingual_0b5d750
MODEL_ID_NEWSAGENCIES ?= ner-newsagency-bert-multilingual_0b5d750
  $(call log.debug, MODEL_ID_NEWSAGENCIES)


# USER-VARIABLE: HF_MODEL_NEWSAGENCIES
# The HuggingFace model ID passed to NewsAgenciesPipeline
#
# Full HuggingFace repository ID, optionally with a revision suffix (@commit or @branch).
# Example: impresso-project/ner-newsagency-bert-multilingual
#          impresso-project/ner-newsagency-bert-multilingual@0b5d75000b6a2db33f0598cca532c103404fd523
HF_MODEL_NEWSAGENCIES ?= impresso-project/ner-newsagency-bert-multilingual
  $(call log.debug, HF_MODEL_NEWSAGENCIES)


# USER-VARIABLE: RUN_VERSION_NEWSAGENCIES
# The version of the processing run
#
# Indicates the version of the current processing run.
RUN_VERSION_NEWSAGENCIES ?= v1-0-0
  $(call log.debug, RUN_VERSION_NEWSAGENCIES)


# VARIABLE: RUN_ID_NEWSAGENCIES
# Unique identifier for the processing run
#
# Constructs a unique identifier based on the process label, task, model, and version.
RUN_ID_NEWSAGENCIES := $(PROCESS_LABEL_NEWSAGENCIES)-$(TASK_NEWSAGENCIES)-$(MODEL_ID_NEWSAGENCIES)_$(RUN_VERSION_NEWSAGENCIES)
  $(call log.debug, RUN_ID_NEWSAGENCIES)


# VARIABLE: PATH_NEWSAGENCIES
# Path for newsagencies processing data
#
# Defines the full path for newsagencies processing data.
PATH_NEWSAGENCIES := $(S3_BUCKET_newsagencies)/$(PROCESS_LABEL_NEWSAGENCIES)$(PROCESS_SUBTYPE_LABEL_NEWSAGENCIES)/$(RUN_ID_NEWSAGENCIES)/$(NEWSPAPER)
  $(call log.debug, PATH_NEWSAGENCIES)


# VARIABLE: S3_PATH_NEWSAGENCIES
# S3 path for input data
#
# Defines the full S3 path where processed newsagencies processing data is stored.
S3_PATH_NEWSAGENCIES := s3://$(PATH_NEWSAGENCIES)
  $(call log.debug, S3_PATH_NEWSAGENCIES)


# VARIABLE: LOCAL_PATH_NEWSAGENCIES
# Local path for storing S3 data
#
# Defines the local storage path for newsagencies processing data within BUILD_DIR.
LOCAL_PATH_NEWSAGENCIES := $(BUILD_DIR)/$(PATH_NEWSAGENCIES)
  $(call log.debug, LOCAL_PATH_NEWSAGENCIES)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_newsagencies.mk)
