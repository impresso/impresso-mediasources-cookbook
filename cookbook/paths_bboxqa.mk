$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_bboxqa.mk)

###############################################################################
# BOUNDARY BOX QUALITY ASSESSMENT PATH DEFINITIONS
# Configuration of input/output paths for boundary box quality assessment processing
###############################################################################


# VARIABLE: S3_BUCKET_BBOXQA
# S3 bucket name for storing processed boundary box quality assessment data
S3_BUCKET_BBOXQA ?= 140-processed-data-sandbox
  $(call log.debug, S3_BUCKET_BBOXQA)


# USER-VARIABLE: PROCESS_LABEL_BBOXQA
# Label for the boundary box quality assessment process
PROCESS_LABEL_BBOXQA ?= bboxqa
  $(call log.debug, PROCESS_LABEL_BBOXQA)


# USER-VARIABLE: PROCESS_SUBTYPE_LABEL_BBOXQA
# Optional subtype label for further process categorization
PROCESS_SUBTYPE_LABEL_BBOXQA ?=
  $(call log.debug, PROCESS_SUBTYPE_LABEL_BBOXQA)


# USER-VARIABLE: TASK_BBOXQA
# Task specification for boundary box quality assessment
# @FIX NOT USED: Example of unused configuration:
# s3://42-processed-data-final/bboxqa/bboxqa_v1-4-4/ACI/ACI-1832.jsonl.bz2
TASK_BBOXQA ?=


# USER-VARIABLE: MODEL_ID_BBOXQA
# Model identifier for the boundary box quality assessment process
# @FIX Example path: s3://42-processed-data-final/bboxqa/bboxqa_v1-4-4/ACI/ACI-1832.jsonl.bz2
MODEL_ID_BBOXQA ?=


# USER-VARIABLE: RUN_VERSION_BBOXQA
# Version identifier for the current boundary box quality assessment run
RUN_VERSION_BBOXQA ?= v1-0-0
  $(call log.debug, RUN_VERSION_BBOXQA)


# VARIABLE: RUN_ID_BBOXQA
# Constructed run identifier combining process label and version
RUN_ID_BBOXQA ?= $(PROCESS_LABEL_BBOXQA)_$(RUN_VERSION_BBOXQA)
  $(call log.debug, RUN_ID_BBOXQA)


# VARIABLE: PATH_BBOXQA
# Path for boundary box quality assessment processing data
#
# Defines the suffix path for boundary box processing data.
PATH_BBOXQA := $(S3_BUCKET_BBOXQA)/$(PROCESS_LABEL_BBOXQA)/$(RUN_ID_BBOXQA)/$(NEWSPAPER)
  $(call log.debug, PATH_BBOXQA)


# VARIABLE: S3_PATH_BBOXQA
# S3 storage path for the processed boundary box quality assessment results
S3_PATH_BBOXQA := s3://$(PATH_BBOXQA)
  $(call log.debug, S3_PATH_BBOXQA)


# VARIABLE: LOCAL_PATH_BBOXQA
# Local file system path for the processed boundary box quality assessment results
LOCAL_PATH_BBOXQA := $(BUILD_DIR)/$(PATH_BBOXQA)
  $(call log.debug, LOCAL_PATH_BBOXQA)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_bboxqa.mk)
