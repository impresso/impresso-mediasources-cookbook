$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_TEMPLATE.mk)
###############################################################################
# TEMPLATE Configuration
# Defines S3 and local paths for TEMPLATE processing
###############################################################################


# USER-VARIABLE: S3_BUCKET_TEMPLATE
# The input bucket for TEMPLATE processing
#
# Defines the S3 bucket where the processed data is stored.
S3_BUCKET_TEMPLATE ?= 140-processed-data-sandbox
  $(call log.debug, S3_BUCKET_TEMPLATE)


# USER-VARIABLE: PROCESS_LABEL_TEMPLATE
# Label for the processing task
#
# A general label for identifying TEMPLATE processing tasks.
PROCESS_LABEL_TEMPLATE ?= template
  $(call log.debug, PROCESS_LABEL_TEMPLATE)


# USER-VARIABLE: PROCESS_SUBTYPE_LABEL_TEMPLATE
# Subtype label for processing
#
# Optional additional label for subtypes of processing.
PROCESS_SUBTYPE_LABEL_TEMPLATE ?=
  $(call log.debug, PROCESS_SUBTYPE_LABEL_TEMPLATE)


# USER-VARIABLE: TASK_TEMPLATE
# The specific TEMPLATE processing task
#
# Defines the specific TEMPLATE processing task.
TASK_TEMPLATE ?= template
  $(call log.debug, TASK_TEMPLATE)


# USER-VARIABLE: MODEL_ID_TEMPLATE
# The model identifier
#
# Specifies the model used for TEMPLATE processing.
MODEL_ID_TEMPLATE ?= template_v0.0.0
  $(call log.debug, MODEL_ID_TEMPLATE)


# USER-VARIABLE: RUN_VERSION_TEMPLATE
# The version of the processing run
#
# Indicates the version of the current processing run.
RUN_VERSION_TEMPLATE ?= v1-0-0
  $(call log.debug, RUN_VERSION_TEMPLATE)


# VARIABLE: RUN_ID_TEMPLATE
# Unique identifier for the processing run
#
# Constructs a unique identifier based on the process label, task, model, and version.
RUN_ID_TEMPLATE := $(PROCESS_LABEL_TEMPLATE)-$(TASK_TEMPLATE)-$(MODEL_ID_TEMPLATE)_$(RUN_VERSION_TEMPLATE)
  $(call log.debug, RUN_ID_TEMPLATE)


# VARIABLE: PATH_TEMPLATE
# Path for TEMPLATE processing data
#
# Defines the full path for TEMPLATE processing data.
PATH_TEMPLATE := $(S3_BUCKET_TEMPLATE)/$(PROCESS_LABEL_TEMPLATE)$(PROCESS_SUBTYPE_LABEL_TEMPLATE)/$(RUN_ID_TEMPLATE)/$(NEWSPAPER)
  $(call log.debug, PATH_TEMPLATE)


# VARIABLE: S3_PATH_TEMPLATE
# S3 path for input data
#
# Defines the full S3 path where processed TEMPLATE processing data is stored.
S3_PATH_TEMPLATE := s3://$(PATH_TEMPLATE)
  $(call log.debug, S3_PATH_TEMPLATE)


# VARIABLE: LOCAL_PATH_TEMPLATE
# Local path for storing S3 data
#
# Defines the local storage path for TEMPLATE processing data within BUILD_DIR.
LOCAL_PATH_TEMPLATE := $(BUILD_DIR)/$(PATH_TEMPLATE)
  $(call log.debug, LOCAL_PATH_TEMPLATE)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_TEMPLATE.mk)
