$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/lingproc.mk)
###############################################################################
# Linguistic Processing Configuration
# Defines S3 and local paths for linguistic processing tasks
###############################################################################


# USER-VARIABLE: S3_BUCKET_LINGPROC
# The input bucket for linguistic processing
#
# Defines the S3 bucket where the processed data is stored.
S3_BUCKET_LINGPROC ?= 142-processed-data-final
  $(call log.debug, S3_BUCKET_LINGPROC)


# USER-VARIABLE: PROCESS_LABEL_LINGPROC
# Label for the processing task
#
# A general label for identifying linguistic processing tasks.
PROCESS_LABEL_LINGPROC ?= lingproc
  $(call log.debug, PROCESS_LABEL_LINGPROC)


# USER-VARIABLE: PROCESS_SUBTYPE_LABEL_LINGPROC
# Subtype label for processing
#
# Optional additional label for subtypes of processing.
PROCESS_SUBTYPE_LABEL_LINGPROC ?=
  $(call log.debug, PROCESS_SUBTYPE_LABEL_LINGPROC)


# USER-VARIABLE: TASK_LINGPROC
# The specific linguistic processing task
#
# Defines the specific linguistic processing task (e.g., POS tagging).
TASK_LINGPROC ?= pos
  $(call log.debug, TASK_LINGPROC)


# USER-VARIABLE: MODEL_ID_LINGPROC
# The model identifier
#
# Specifies the model used for linguistic processing.
MODEL_ID_LINGPROC ?= spacy_v3.6.0-multilingual
  $(call log.debug, MODEL_ID_LINGPROC)


# USER-VARIABLE: RUN_VERSION_LINGPROC
# The version of the processing run
#
# Indicates the version of the current processing run.
RUN_VERSION_LINGPROC ?= v2-0-0
  $(call log.debug, RUN_VERSION_LINGPROC)


# VARIABLE: RUN_ID_LINGPROC
# Unique identifier for the processing run
#
# Constructs a unique identifier based on the process label, task, model, and version.
RUN_ID_LINGPROC := $(PROCESS_LABEL_LINGPROC)-$(TASK_LINGPROC)-$(MODEL_ID_LINGPROC)_$(RUN_VERSION_LINGPROC)
  $(call log.debug, RUN_ID_LINGPROC)


# VARIABLE: PATH_LINGPROC_BASE
# Path for linguistic processing data without newspaper
#
# Defines the full path for linguistic processing data without the newspaper component.
PATH_LINGPROC_BASE := $(S3_BUCKET_LINGPROC)/$(PROCESS_LABEL_LINGPROC)$(PROCESS_SUBTYPE_LABEL_LINGPROC)/$(RUN_ID_LINGPROC)
  $(call log.debug, PATH_LINGPROC_BASE)



# VARIABLE: PATH_LINGPROC
# Path for linguistic processing data for newspaper
#
# Defines the full path of a newspaper for linguistic processing data.
PATH_LINGPROC := $(PATH_LINGPROC_BASE)/$(NEWSPAPER)
  $(call log.debug, PATH_LINGPROC)


# VARIABLE: S3_PATH_LINGPROC
# S3 path for input data
#
# Defines the full S3 path where processed linguistic data is stored.
S3_PATH_LINGPROC := s3://$(PATH_LINGPROC)
  $(call log.debug, S3_PATH_LINGPROC)


# VARIABLE: LOCAL_PATH_LINGPROC
# Local path for storing S3 data
#
# Defines the local storage path for linguistic processing data within BUILD_DIR.
LOCAL_PATH_LINGPROC := $(BUILD_DIR)/$(PATH_LINGPROC)
  $(call log.debug, LOCAL_PATH_LINGPROC)

help-path-variables::
	@echo ""
	@echo "LINGPROC PATHS:"
	@echo "  S3_BUCKET_LINGPROC=$(S3_BUCKET_LINGPROC)"
	@echo "  RUN_ID_LINGPROC=$(RUN_ID_LINGPROC)"
	@echo "  PATH_LINGPROC_BASE=$(PATH_LINGPROC_BASE)"
	@echo "  S3_PATH_LINGPROC=$(S3_PATH_LINGPROC)"
	@echo "  LOCAL_PATH_LINGPROC=$(LOCAL_PATH_LINGPROC)"


$(call log.debug, COOKBOOK END INCLUDE: cookbook/lingproc.mk)
