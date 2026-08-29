$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/ocrqa.mk)
###############################################################################
# OCR Quality Assessment Configuration
# Defines S3 and local paths for OCR quality assessment tasks
###############################################################################


# USER-VARIABLE: S3_BUCKET_OCRQA
# The input bucket for OCR quality assessment
#
# Defines the S3 bucket where the processed data is stored.
S3_BUCKET_OCRQA ?= 40-processed-data-sandbox
  $(call log.debug, S3_BUCKET_OCRQA)


# USER-VARIABLE: PROCESS_LABEL_OCRQA
# Label for the processing task
#
# A general label for identifying OCR quality assessment tasks.
PROCESS_LABEL_OCRQA ?= ocrqa
  $(call log.debug, PROCESS_LABEL_OCRQA)


# USER-VARIABLE: PROCESS_SUBTYPE_LABEL_OCRQA
# Subtype label for processing
#
# Optional additional label for subtypes of processing.
PROCESS_SUBTYPE_LABEL_OCRQA ?=
  $(call log.debug, PROCESS_SUBTYPE_LABEL_OCRQA)


# USER-VARIABLE: TASK_OCRQA
# The specific OCR quality assessment task
#
# Defines the specific OCR quality assessment task.
TASK_OCRQA ?= ocrqa
  $(call log.debug, TASK_OCRQA)


# USER-VARIABLE: MODEL_ID_OCRQA
# The model identifier
#
# Specifies the model used for OCR quality assessment.
MODEL_ID_OCRQA ?= wp_v1.0.5
  $(call log.debug, MODEL_ID_OCRQA)


# USER-VARIABLE: RUN_VERSION_OCRQA
# The version of the processing run
#
# Indicates the version of the current processing run.
RUN_VERSION_OCRQA ?= v1-0-0
  $(call log.debug, RUN_VERSION_OCRQA)


# VARIABLE: RUN_ID_OCRQA
# Unique identifier for the processing run
#
# Constructs a unique identifier based on the process label, task, model, and version.
RUN_ID_OCRQA := $(PROCESS_LABEL_OCRQA)-$(TASK_OCRQA)-$(MODEL_ID_OCRQA)_$(RUN_VERSION_OCRQA)
  $(call log.debug, RUN_ID_OCRQA)


# VARIABLE: PATH_OCRQA
# Path for OCR quality assessment data
#
# Defines the full path for OCR quality assessment data.
PATH_OCRQA := $(S3_BUCKET_OCRQA)/$(PROCESS_LABEL_OCRQA)$(PROCESS_SUBTYPE_LABEL_OCRQA)/$(RUN_ID_OCRQA)/$(NEWSPAPER)
  $(call log.debug, PATH_OCRQA)


# VARIABLE: S3_PATH_OCRQA
# S3 path for input data
#
# Defines the full S3 path where processed OCR quality assessment data is stored.
S3_PATH_OCRQA := s3://$(PATH_OCRQA)
  $(call log.debug, S3_PATH_OCRQA)


# VARIABLE: LOCAL_PATH_OCRQA
# Local path for storing S3 data
#
# Defines the local storage path for OCR quality assessment data within BUILD_DIR.
LOCAL_PATH_OCRQA := $(BUILD_DIR)/$(PATH_OCRQA)
  $(call log.debug, LOCAL_PATH_OCRQA)

help-path-variables::
	@echo ""
	@echo "OCRQA PATHS:"
	@echo "  S3_BUCKET_OCRQA=$(S3_BUCKET_OCRQA)"
	@echo "  RUN_ID_OCRQA=$(RUN_ID_OCRQA)"
	@echo "  S3_PATH_OCRQA=$(S3_PATH_OCRQA)"
	@echo "  LOCAL_PATH_OCRQA=$(LOCAL_PATH_OCRQA)"


$(call log.debug, COOKBOOK END INCLUDE: cookbook/ocrqa.mk)
