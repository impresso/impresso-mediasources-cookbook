$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_mediasources.mk)
###############################################################################
# mediasources Configuration
# Defines S3 and local paths for media-source NER processing
###############################################################################


# USER-VARIABLE: S3_BUCKET_MEDIASOURCES
# S3 bucket where processed media-source output is stored.
S3_BUCKET_MEDIASOURCES ?= 141-processed-data-staging
  $(call log.debug, S3_BUCKET_MEDIASOURCES)


# USER-VARIABLE: PROCESS_LABEL_MEDIASOURCES
# Label for the processing task.
PROCESS_LABEL_MEDIASOURCES ?= mediasources
  $(call log.debug, PROCESS_LABEL_MEDIASOURCES)


# USER-VARIABLE: PROCESS_SUBTYPE_LABEL_MEDIASOURCES
# Optional additional label for processing subtypes.
PROCESS_SUBTYPE_LABEL_MEDIASOURCES ?= $(EMPTY)
  $(call log.debug, PROCESS_SUBTYPE_LABEL_MEDIASOURCES)


# USER-VARIABLE: TASK_MEDIASOURCES
# The specific media-source processing task.
TASK_MEDIASOURCES ?= ner
  $(call log.debug, TASK_MEDIASOURCES)


# USER-VARIABLE: MODEL_ID_MEDIASOURCES
# Path-safe model identifier used in S3 paths.
MODEL_ID_MEDIASOURCES ?= mmbert-impresso-mediasources-ner_v2-0-0
  $(call log.debug, MODEL_ID_MEDIASOURCES)


# USER-VARIABLE: HF_MODEL_MEDIASOURCES
# Hugging Face model ID passed to MediaSourcesPipeline.
HF_MODEL_MEDIASOURCES ?= impresso-project/mmbert-impresso-mediasources-ner
  $(call log.debug, HF_MODEL_MEDIASOURCES)


# USER-VARIABLE: HF_MODEL_REVISION_MEDIASOURCES
# Hugging Face revision passed to MediaSourcesPipeline.
HF_MODEL_REVISION_MEDIASOURCES ?= v2.0.0
  $(call log.debug, HF_MODEL_REVISION_MEDIASOURCES)


# USER-VARIABLE: RUN_VERSION_MEDIASOURCES
# Version of the processing run.
RUN_VERSION_MEDIASOURCES ?= v1-0-0
  $(call log.debug, RUN_VERSION_MEDIASOURCES)


# VARIABLE: RUN_ID_MEDIASOURCES
# Unique identifier for the processing run.
RUN_ID_MEDIASOURCES := $(PROCESS_LABEL_MEDIASOURCES)-$(TASK_MEDIASOURCES)-$(MODEL_ID_MEDIASOURCES)_$(RUN_VERSION_MEDIASOURCES)
  $(call log.debug, RUN_ID_MEDIASOURCES)


# VARIABLE: PATH_MEDIASOURCES
# Path for media-source processing data.
PATH_MEDIASOURCES := $(S3_BUCKET_MEDIASOURCES)/$(PROCESS_LABEL_MEDIASOURCES)$(PROCESS_SUBTYPE_LABEL_MEDIASOURCES)/$(RUN_ID_MEDIASOURCES)/$(NEWSPAPER)
  $(call log.debug, PATH_MEDIASOURCES)


# VARIABLE: S3_PATH_MEDIASOURCES
# S3 path where processed media-source data is stored.
S3_PATH_MEDIASOURCES := s3://$(PATH_MEDIASOURCES)
  $(call log.debug, S3_PATH_MEDIASOURCES)


# VARIABLE: LOCAL_PATH_MEDIASOURCES
# Local path for media-source processing data within BUILD_DIR.
LOCAL_PATH_MEDIASOURCES := $(BUILD_DIR)/$(PATH_MEDIASOURCES)
  $(call log.debug, LOCAL_PATH_MEDIASOURCES)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_mediasources.mk)

