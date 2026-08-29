$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_nel.mk)
###############################################################################
# nel Configuration
# Defines S3 and local paths for nel processing
###############################################################################


# USER-VARIABLE: S3_BUCKET_NEL
# The input bucket for nel processing
#
# Defines the S3 bucket where the processed data is stored.
S3_BUCKET_NEL ?= 42-processed-data-final
  $(call log.debug, S3_BUCKET_NEL)


# USER-VARIABLE: PROCESS_LABEL_NEL
# Label for the processing task
#
# A general label for identifying nel processing tasks.
PROCESS_LABEL_NEL ?= entities
  $(call log.debug, PROCESS_LABEL_NEL)


# USER-VARIABLE: PROCESS_SUBTYPE_LABEL_NEL
# Subtype label for processing
#
# Optional additional label for subtypes of processing.
PROCESS_SUBTYPE_LABEL_NEL ?= $(EMPTY)
  $(call log.debug, PROCESS_SUBTYPE_LABEL_NEL)


# USER-VARIABLE: TASK_NEL
# The specific nel processing task
#
# Defines the specific nel processing task.
TASK_NEL ?= entities
  $(call log.debug, TASK_NEL)


# USER-VARIABLE: MODEL_ID_NEL
# The model identifier
#
# Specifies the model used for nel processing.
MODEL_ID_NEL ?= bert-historic-multilingual
  $(call log.debug, MODEL_ID_NEL)


# USER-VARIABLE: RUN_VERSION_NEL
# The version of the processing run
#
# Indicates the version of the current processing run.
RUN_VERSION_NEL ?= v4-0-1
  $(call log.debug, RUN_VERSION_NEL)


# VARIABLE: RUN_ID_NEL
# Unique identifier for the processing run
#
# Constructs a unique identifier based on the process label, task, model, and version.
RUN_ID_NEL := $(TASK_NEL)-$(MODEL_ID_NEL)_$(RUN_VERSION_NEL)
  $(call log.debug, RUN_ID_NEL)


# VARIABLE: PATH_NEL
# Path for nel processing data
#
# Defines the full path for nel processing data.
PATH_NEL := $(S3_BUCKET_NEL)/$(PROCESS_LABEL_NEL)/$(RUN_ID_NEL)/$(NEWSPAPER)
  $(call log.debug, PATH_NEL)


# VARIABLE: S3_PATH_NEL
# S3 path for input data
#
# Defines the full S3 path where processed nel processing data is stored.
S3_PATH_NEL := s3://$(PATH_NEL)
  $(call log.debug, S3_PATH_NEL)


# VARIABLE: LOCAL_PATH_NEL
# Local path for storing S3 data
#
# Defines the local storage path for nel processing data within BUILD_DIR.
LOCAL_PATH_NEL := $(BUILD_DIR)/$(PATH_NEL)
  $(call log.debug, LOCAL_PATH_NEL)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_nel.mk)
