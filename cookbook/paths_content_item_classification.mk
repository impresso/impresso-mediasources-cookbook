$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_content_item_classification.mk)
###############################################################################
# content_item_classification Configuration
# Defines S3 and local paths for content_item_classification processing
###############################################################################


# USER-VARIABLE: S3_BUCKET_content_item_classification
# The input bucket for content_item_classification processing
#
# Defines the S3 bucket where the processed data is stored.
S3_BUCKET_content_item_classification ?= 140-processed-data-sandbox
  $(call log.debug, S3_BUCKET_content_item_classification)


# USER-VARIABLE: PROCESS_LABEL_content_item_classification
# Label for the processing task
#
# A general label for identifying content_item_classification processing tasks.
PROCESS_LABEL_content_item_classification ?= content-item-classification
  $(call log.debug, PROCESS_LABEL_content_item_classification)


# USER-VARIABLE: PROCESS_SUBTYPE_LABEL_content_item_classification
# Subtype label for processing
#
# Optional additional label for subtypes of processing.
PROCESS_SUBTYPE_LABEL_content_item_classification ?=
  $(call log.debug, PROCESS_SUBTYPE_LABEL_content_item_classification)


# USER-VARIABLE: TASK_content_item_classification
# The specific content_item_classification processing task
#
# Defines the specific content_item_classification processing task.
TASK_content_item_classification ?= base
  $(call log.debug, TASK_content_item_classification)


# USER-VARIABLE: MODEL_ID_content_item_classification
# The model identifier
#
# Specifies the model used for content_item_classification processing.
MODEL_ID_content_item_classification ?= multilingual
  $(call log.debug, MODEL_ID_content_item_classification)


# USER-VARIABLE: HF_MODEL_CONTENT_ITEM_CLASSIFICATION
# HuggingFace model identifier for ad classification
#
# Specifies the full HuggingFace model repository path with optional :revision suffix.
# Format: model-name or model-name:revision
# Example: impresso-project/impresso-ad-classification-xlm-one-class:v2.0
# Default: impresso-project/impresso-ad-classification-xlm-one-class:v2.0
HF_MODEL_CONTENT_ITEM_CLASSIFICATION ?= impresso-project/impresso-ad-classification-xlm-one-class:v2.0
  $(call log.debug, HF_MODEL_CONTENT_ITEM_CLASSIFICATION)


# USER-VARIABLE: RUN_VERSION_content_item_classification
# The version of the processing run
#
# Indicates the version of the current processing run.
RUN_VERSION_content_item_classification ?= v1-0-0
  $(call log.debug, RUN_VERSION_content_item_classification)


# VARIABLE: RUN_ID_content_item_classification
# Unique identifier for the processing run
#
# Constructs a unique identifier based on the process label, task, model, and version.
RUN_ID_content_item_classification := $(PROCESS_LABEL_content_item_classification)-$(TASK_content_item_classification)-$(MODEL_ID_content_item_classification)_$(RUN_VERSION_content_item_classification)
  $(call log.debug, RUN_ID_content_item_classification)


# VARIABLE: PATH_content_item_classification
# Path for content_item_classification processing data
#
# Defines the full path for content_item_classification processing data.
PATH_content_item_classification := $(S3_BUCKET_content_item_classification)/$(PROCESS_LABEL_content_item_classification)$(PROCESS_SUBTYPE_LABEL_content_item_classification)/$(RUN_ID_content_item_classification)/$(NEWSPAPER)
  $(call log.debug, PATH_content_item_classification)


# VARIABLE: S3_PATH_content_item_classification
# S3 path for input data
#
# Defines the full S3 path where processed content_item_classification processing data is stored.
S3_PATH_content_item_classification := s3://$(PATH_content_item_classification)
  $(call log.debug, S3_PATH_content_item_classification)


# VARIABLE: LOCAL_PATH_content_item_classification
# Local path for storing S3 data
#
# Defines the local storage path for content_item_classification processing data within BUILD_DIR.
LOCAL_PATH_content_item_classification := $(BUILD_DIR)/$(PATH_content_item_classification)
  $(call log.debug, LOCAL_PATH_content_item_classification)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_content_item_classification.mk)
