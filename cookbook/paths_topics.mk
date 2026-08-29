$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_topics.mk)

###############################################################################
# Paths and Identifiers for Topic Processing
#
# Defines various paths and identifiers used in processing topics, 
# including S3 and local storage locations, versioning, and model specifics.
###############################################################################


# USER-VARIABLE: S3_BUCKET_TOPICS
# The S3 bucket where processed topic data is staged
S3_BUCKET_TOPICS ?= 41-processed-data-staging
$(call log.debug, S3_BUCKET_TOPICS)


# USER-VARIABLE: PROCESS_LABEL_TOPICS
# Label for the processing step
PROCESS_LABEL_TOPICS ?= topics
  $(call log.debug, PROCESS_LABEL_TOPICS)


# USER-VARIABLE: RUN_VERSION_TOPICS
# Version identifier for the topic processing run
RUN_VERSION_TOPICS ?= v2-0-1
  $(call log.debug, RUN_VERSION_TOPICS)


# USER-VARIABLE: TASK_TOPICS
# Task identifier for topic modeling
TASK_TOPICS ?= tm
  $(call log.debug, TASK_TOPICS)


# USER-VARIABLE: MALLET_RANDOM_SEED
# Random seed used for Mallet topic modeling
MALLET_RANDOM_SEED ?= 42
  $(call log.debug, MALLET_RANDOM_SEED)


# VARIABLE: MODEL_SPECIFICITY_TOPICS
# Defines model specificity based on Mallet seed
MODEL_SPECIFICITY_TOPICS ?= mallet_infer_seed$(MALLET_RANDOM_SEED)
  $(call log.debug, MODEL_SPECIFICITY_TOPICS)


# USER-VARIABLE: MODEL_VERSION_TOPICS
# Version identifier for the topic model
MODEL_VERSION_TOPICS ?= v2.0.1
  $(call log.debug, MODEL_VERSION_TOPICS)


# USER-VARIABLE: LANG_TOPICS
# Language specification for the topic model
LANG_TOPICS ?= multilingual
  $(call log.debug, LANG_TOPICS)


# VARIABLE: MODEL_ID_TOPICS
# Constructs the model ID based on task, specificity, version, and language
MODEL_ID_TOPICS ?= $(TASK_TOPICS)-$(MODEL_SPECIFICITY_TOPICS)_$(MODEL_VERSION_TOPICS)-$(LANG_TOPICS)
  $(call log.debug, MODEL_ID_TOPICS)


# VARIABLE: RUN_ID_TOPICS
# Constructs the run ID based on processing label, model ID, and run version
RUN_ID_TOPICS ?= $(PROCESS_LABEL_TOPICS)-$(MODEL_ID_TOPICS)_$(RUN_VERSION_TOPICS)
  $(call log.debug, RUN_ID_TOPICS)

# VARIABLE: PATH_TOPICS
# Path for processed topics data
#
# Defines the suffix path for linguistic processing data.
PATH_TOPICS := $(S3_BUCKET_TOPICS)/$(PROCESS_LABEL_TOPICS)/$(RUN_ID_TOPICS)/$(NEWSPAPER)
  $(call log.debug, PATH_TOPICS)


# VARIABLE: S3_PATH_TOPICS
# Defines the S3 path where processed topics are stored
S3_PATH_TOPICS := s3://$(PATH_TOPICS)
  $(call log.debug, S3_PATH_TOPICS)


# VARIABLE: LOCAL_PATH_TOPICS
# Defines the local path where processed topics are stored
LOCAL_PATH_TOPICS := $(BUILD_DIR)/$(PATH_TOPICS)
  $(call log.debug, LOCAL_PATH_TOPICS)


$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_topics.mk)
