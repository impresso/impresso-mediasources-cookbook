$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_langident.mk)

###############################################################################
# LANGUAGE IDENTIFICATION PATH DEFINITIONS
# Configuration of input/output paths for language identification processing
###############################################################################


# VARIABLE: S3_BUCKET_LANGIDENT
# S3 bucket name for storing processed language identification data
S3_BUCKET_LANGIDENT ?= 140-processed-data-sandbox
  $(call log.debug, S3_BUCKET_LANGIDENT)

# VARIABLE: S3_BUCKET_LANGIDENT_STAGE1
# S3 bucket name for storing processed language identification data
S3_BUCKET_LANGIDENT_STAGE1 ?= 130-component-sandbox
  $(call log.debug, S3_BUCKET_LANGIDENT_STAGE1)


# USER-VARIABLE: PROCESS_LABEL_LANGIDENT
# Label for the language identification process
PROCESS_LABEL_LANGIDENT ?= langident
  $(call log.debug, PROCESS_LABEL_LANGIDENT)


# USER-VARIABLE: PROCESS_SUBTYPE_LABEL_LANGIDENT
# Optional subtype label for further process categorization
PROCESS_SUBTYPE_LABEL_LANGIDENT ?=
  $(call log.debug, PROCESS_SUBTYPE_LABEL_LANGIDENT)


# USER-VARIABLE: TASK_LANGIDENT
# Task specification for language identification
# @FIX NOT USED: Example of unused configuration:
# s3://42-processed-data-final/langident/langident_v1-4-4/ACI/ACI-1832.jsonl.bz2
TASK_LANGIDENT ?= lid
  $(call log.debug, TASK_LANGIDENT)

# Optional subtype label for further process categorization
TASK_LANGIDENT_STAGE1 ?= lid_stage1
  $(call log.debug, SUBTASK_LANGIDENT_STAGE1)



# USER-VARIABLE: MODEL_ID_LANGIDENT
# Model identifier for the language identification process
# @FIX Example path: s3://42-processed-data-final/langident/langident_v1-4-4/ACI/ACI-1832.jsonl.bz2
MODEL_ID_LANGIDENT ?= ensemble_multilingual


# USER-VARIABLE: RUN_VERSION_LANGIDENT
# Version identifier for the current language identification run
RUN_VERSION_LANGIDENT ?= v2-0-2
  $(call log.debug, RUN_VERSION_LANGIDENT)


# VARIABLE: RUN_ID_LANGIDENT
# Constructed run identifier combining process label and version
RUN_ID_LANGIDENT ?= $(PROCESS_LABEL_LANGIDENT)-$(TASK_LANGIDENT)-$(MODEL_ID_LANGIDENT)_$(RUN_VERSION_LANGIDENT)
  $(call log.debug, RUN_ID_LANGIDENT)

# VARIABLE: RUN_ID_LANGIDENT_STAGE1
# Constructed run identifier combining process label and version
RUN_ID_LANGIDENT_STAGE1 ?= $(PROCESS_LABEL_LANGIDENT)-$(TASK_LANGIDENT_STAGE1)-$(MODEL_ID_LANGIDENT)_$(RUN_VERSION_LANGIDENT)

  $(call log.debug, RUN_ID_LANGIDENT_STAGE1)

# VARIABLE: PATH_LANGIDENT
# Path for language identification processing data
#
# Defines the suffix path for linguistic processing data.
ifeq ($(value USE_CANONICAL),1)
LANGIDENT_PATH_SEGMENT := $(CANONICAL_PATH_SEGMENT)
else
LANGIDENT_PATH_SEGMENT := $(NEWSPAPER)
endif
  $(call log.debug, LANGIDENT_PATH_SEGMENT)

PATH_LANGIDENT := $(S3_BUCKET_LANGIDENT)/$(PROCESS_LABEL_LANGIDENT)/$(RUN_ID_LANGIDENT)/$(LANGIDENT_PATH_SEGMENT)
  $(call log.debug, PATH_LANGIDENT)

# VARIABLE: PATH_LANGIDENT_STAGE1
# Path for language identification component data
#
# Defines component path.
PATH_LANGIDENT_STAGE1 := $(S3_BUCKET_LANGIDENT_STAGE1)/$(PROCESS_LABEL_LANGIDENT)/$(RUN_ID_LANGIDENT_STAGE1)/$(LANGIDENT_PATH_SEGMENT)
  $(call log.debug, PATH_LANGIDENT_STAGE1)

# VARIABLE: S3_PATH_LANGIDENT
# S3 storage path for the processed language identification results
S3_PATH_LANGIDENT := s3://$(PATH_LANGIDENT)
  $(call log.debug, S3_PATH_LANGIDENT)

# VARIABLE: S3_PATH_LANGIDENT_STAGE1
# S3 storage path for the processed language identification results
S3_PATH_LANGIDENT_STAGE1 := s3://$(PATH_LANGIDENT_STAGE1)
  $(call log.debug, S3_PATH_LANGIDENT_STAGE1)

# VARIABLE: LOCAL_PATH_LANGIDENT
# Local file system path for the processed language identification results
LOCAL_PATH_LANGIDENT := $(BUILD_DIR)/$(PATH_LANGIDENT)
  $(call log.debug, LOCAL_PATH_LANGIDENT)

# VARIABLE: LOCAL_PATH_LANGIDENT_STAGE1
# Local file system path for the processed language identification results
LOCAL_PATH_LANGIDENT_STAGE1 := $(BUILD_DIR)/$(PATH_LANGIDENT_STAGE1)
  $(call log.debug, LOCAL_PATH_LANGIDENT_STAGE1)

help-path-variables::
	@echo ""
	@echo "LANGIDENT PATHS:"
	@echo "  S3_BUCKET_LANGIDENT=$(S3_BUCKET_LANGIDENT)"
	@echo "  S3_BUCKET_LANGIDENT_STAGE1=$(S3_BUCKET_LANGIDENT_STAGE1)"
	@echo "  RUN_ID_LANGIDENT=$(RUN_ID_LANGIDENT)"
	@echo "  RUN_ID_LANGIDENT_STAGE1=$(RUN_ID_LANGIDENT_STAGE1)"
	@echo "  S3_PATH_LANGIDENT=$(S3_PATH_LANGIDENT)"
	@echo "  S3_PATH_LANGIDENT_STAGE1=$(S3_PATH_LANGIDENT_STAGE1)"
	@echo "  LOCAL_PATH_LANGIDENT=$(LOCAL_PATH_LANGIDENT)"
	@echo "  LOCAL_PATH_LANGIDENT_STAGE1=$(LOCAL_PATH_LANGIDENT_STAGE1)"


$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_langident.mk)
