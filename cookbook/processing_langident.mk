$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/processing_langident.mk)
###############################################################################
# Orchestrating Language Identification and OCR Quality Assessment
# Makefile for processing impresso language identification (and optionally OCR QA)
#
# === Language Identification Processing Pipeline ===
#
# The language identification pipeline consists of three stages that must execute
# in strict sequence to ensure data dependencies are satisfied:
#
# Stage 1 (Systems): langident-systems-target
#   - Applies multiple LID systems (langid, impresso_ft, wp_ft, etc.) to each content item
#   - Generates stage1 files: $(LOCAL_PATH_LANGIDENT_STAGE1)/NEWSPAPER-YEAR.jsonl.bz2
#   - Each file contains predictions from all configured LID systems
#
# Stage 2 (Statistics): langident-statistics-target
#   - Aggregates statistics across all stage1 files per newspaper
#   - Generates: $(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json
#   - Contains dominant language, language distributions, and confidence metrics
#   - **Depends on Stage 1**: Requires all stage1 files to compute statistics
#
# Stage 3 (Ensemble): langident-ensemble-target
#   - Makes final language decisions using ensemble voting across LID systems
#   - Generates final output: $(LOCAL_PATH_LANGIDENT)/NEWSPAPER-YEAR.jsonl.bz2
#   - **Depends on Stages 1 & 2**: Each ensemble file requires both:
#     * Its corresponding stage1 file (NEWSPAPER-YEAR.jsonl.bz2)
#     * The newspaper statistics file (stats.json)
#
# === Parallel Processing and Sequential Dependencies ===
#
# When running with parallel jobs (e.g., make -j 8), Make will attempt to build
# all targets concurrently unless explicit dependencies prevent it. The phony
# targets (langident-*-target) enforce sequential execution:
#
#   langident-ensemble-target depends on langident-statistics-target
#   langident-statistics-target depends on langident-systems-target
#
# This ensures that even with parallel execution at the file level (processing
# multiple newspapers simultaneously), the three stages complete in order:
#   1. All stage1 files are created
#   2. Statistics file is generated from stage1 files
#   3. Ensemble files are created from stage1 files + statistics
#
# File-level dependencies (e.g., ensemble file depends on stage1 file) ensure
# correct ordering within each stage, while phony target dependencies ensure
# correct ordering between stages.
###############################################################################


# === INTEGRATION HOOKS ========================================================

# USER-VARIABLE: USE_CANONICAL
# Flag to use canonical input instead of rebuilt input.
#
# Set to 1 to use canonical input, empty or 0 for rebuilt input.
USE_CANONICAL ?= 1
  $(call log.debug, USE_CANONICAL)


# Conditional input synchronization based on format
ifeq ($(USE_CANONICAL),1)

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes canonical data when USE_CANONICAL=1.
sync-input :: sync-canonical

else

# DOUBLE-COLON-TARGET: sync-input
# Synchronizes rebuilt data when USE_CANONICAL != 1.
sync-input :: sync-rebuilt

endif


# DOUBLE-COLON-TARGET: sync-output
# Synchronizes processed output language identification data.
#
# This target ensures that language identification output data is
# retrieved from S3 and stored locally for further analysis.
sync-output :: sync-langident


# DOUBLE-COLON-TARGET: clean-sync-output
# Needed for resync-output target to sync fresh output from other machines.
clean-sync-output :: clean-sync-langident


# DOUBLE-COLON-TARGET: processing-target
# Hook target for language identification.
processing-target :: langident-target


# === USER-CONFIGURABLE VARIABLES (Common to all stages) ======================

# USER-VARIABLE: LANGIDENT_LOGGING_LEVEL
# Option to specify logging level for language identification.
#
# Uses the global LOGGING_LEVEL as default, can be overridden for langident-specific logging.
LANGIDENT_LOGGING_LEVEL ?= $(LOGGING_LEVEL)
  $(call log.debug, LANGIDENT_LOGGING_LEVEL)


# USER-VARIABLE: LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION
# Option to specify a default minimal text length for all stages.
#
# The different stages can override this value as needed.
# If the text length is below this threshold, the language identification will not be
# performed or included in statistics or ensemble predictions. The default language will
# be used instead.
# The following USER-VARIABLES default to this value if not set explicitly:
# - LANGIDENT_SYSTEMS_MINIMAL_TEXT_LENGTH_OPTION
# - LANGIDENT_STATISTICS_MINIMAL_TEXT_LENGTH_OPTION
# - LANGIDENT_ENSEMBLE_MINIMAL_TEXT_LENGTH_OPTION
LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION ?= 100
  $(call log.debug, LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION)


# USER-VARIABLE: LANGIDENT_ROUND_NDIGITS_OPTION
# Option to specify the number of decimal places for probability rounding in language identification.
#
# This variable sets the number of decimal places to which language identification probabilities
# will be rounded in the output.
LANGIDENT_ROUND_NDIGITS_OPTION ?= 3
  $(call log.debug, LANGIDENT_ROUND_NDIGITS_OPTION)


# USER-VARIABLE: LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION
# Option to specify the threshold for the ratio of alphabetical characters in systems.
#
# This variable sets the minimum ratio of alphabetical characters required for a text to
# be considered for language identification in systems processing.
# If the ratio of alphabetical characters is below this threshold, the text will not be
# processed for language identification.
# This is used to filter out texts that may not be suitable for language identification
# due to a low proportion of alphabetical content.
LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION ?= 0.5
  $(call log.debug, LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION)


# === USER-CONFIGURABLE VARIABLES (Stage 1: Systems) ==========================

# USER-VARIABLE: LANGIDENT_SYSTEMS_LIDS_OPTION
# Option to specify language identification systems to use.
#
# This variable allows the user to select which language identification systems
# will be used in the processing.
# Available systems:
# - langid: Original langid.py library (supports many languages including 'lb')
# - langdetect: Python port of Google's language-detection library (many languages, no 'lb')
# - wp_ft: Wikipedia FastText model (supports many languages including 'lb')
# - impresso_ft: Custom Impresso FastText model (supports fr/de/lb/en/it)
# - impresso_langident_pipeline: Impresso-specific pipeline from impresso-pipelines
# - lingua: Lingua language detector (high accuracy, supports many languages including 'lb')
# The user can modify this variable to include or exclude specific systems as needed.
LANGIDENT_SYSTEMS_LIDS_OPTION ?= langid impresso_ft wp_ft impresso_langident_pipeline lingua
  $(call log.info, LANGIDENT_SYSTEMS_LIDS_OPTION)


# USER-VARIABLE: LANGIDENT_SYSTEMS_IMPPRESSO_FASTTEXT_MODEL_OPTION
# Option to specify the Impresso FastText model for language identification.
#
# This variable allows the user to set the path to the Impresso FastText model
# that will be used in the language identification processing.
LANGIDENT_SYSTEMS_IMPPRESSO_FASTTEXT_MODEL_OPTION ?= models/fasttext/impresso-lid.bin
  $(call log.debug, LANGIDENT_SYSTEMS_IMPPRESSO_FASTTEXT_MODEL_OPTION)


# USER-VARIABLE: LANGIDENT_SYSTEMS_WP_FASTTEXT_MODEL_OPTION
# Option to specify the Wikipedia FastText model for language identification.
#
# This variable allows the user to set the path to the Wikipedia FastText model
# that will be used in the language identification processing.
LANGIDENT_SYSTEMS_WP_FASTTEXT_MODEL_OPTION ?= models/fasttext/lid.176.bin
  $(call log.debug, LANGIDENT_SYSTEMS_WP_FASTTEXT_MODEL_OPTION)


# USER-VARIABLE: LANGIDENT_SYSTEMS_MINIMAL_TEXT_LENGTH_OPTION
# Option to specify the minimal text length for systems language identification.
#
# This variable sets the minimum length of text that will be considered for
# language identification in systems processing.
# If the text length is below this threshold, the language identification will not be
# performed.
LANGIDENT_SYSTEMS_MINIMAL_TEXT_LENGTH_OPTION ?= $(LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION)
  $(call log.debug, LANGIDENT_SYSTEMS_MINIMAL_TEXT_LENGTH_OPTION)


# USER-VARIABLE: LANGIDENT_SYSTEMS_MINIMAL_LID_PROBABILITY_OPTION
# Minimal probability for a LID decision to be considered in systems processing.
LANGIDENT_SYSTEMS_MINIMAL_LID_PROBABILITY_OPTION ?= 0.5
  $(call log.debug, LANGIDENT_SYSTEMS_MINIMAL_LID_PROBABILITY_OPTION)


# === USER-CONFIGURABLE VARIABLES (Stage 2: Statistics) =======================

# USER-VARIABLE: LANGIDENT_STATISTICS_MINIMAL_TEXT_LENGTH_OPTION
# Option to specify the minimal text length for statistics language identification.
#
# This variable sets the minimum length of text that will be considered for
# language identification in statistics processing.
# If the text length is below this threshold, the language identification will not be
# performed.
# This is used to filter out very short texts that may not provide enough context for
# accurate language identification.
LANGIDENT_STATISTICS_MINIMAL_TEXT_LENGTH_OPTION ?= $(LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION)
  $(call log.debug, LANGIDENT_STATISTICS_MINIMAL_TEXT_LENGTH_OPTION)


# USER-VARIABLE: LANGIDENT_STATISTICS_BOOST_FACTOR_OPTION
# Option to specify the boost factor for language identification scoring.
#
# This variable sets the factor by which the scores of certain languages are boosted
# during the language identification process.
# It is used to adjust the influence of specific languages in the scoring mechanism,
# allowing for more flexibility in how languages are prioritized based on their scores.
LANGIDENT_STATISTICS_BOOST_FACTOR_OPTION ?= 1.5
  $(call log.debug, LANGIDENT_STATISTICS_BOOST_FACTOR_OPTION)


# USER-VARIABLE: LANGIDENT_STATISTICS_MINIMAL_VOTE_SCORE_OPTION
# Option to specify the minimal vote score for statistics generation.
LANGIDENT_STATISTICS_MINIMAL_VOTE_SCORE_OPTION ?= 0.5
  $(call log.debug, LANGIDENT_STATISTICS_MINIMAL_VOTE_SCORE_OPTION)


# === USER-CONFIGURABLE VARIABLES (Stage 3: Ensemble) =========================

# USER-VARIABLE: LANGIDENT_ENSEMBLE_MINIMAL_TEXT_LENGTH_OPTION
# Option to specify the minimal text length for ensemble language identification.
#
# This variable sets the minimum length of text that will be considered for
# language identification in ensemble processing.
# If the text length is below this threshold, the language identification will not be
# performed.
# This is used to ensure that only sufficiently long texts are processed in ensemble.
LANGIDENT_ENSEMBLE_MINIMAL_TEXT_LENGTH_OPTION ?= $(LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION)
  $(call log.debug, LANGIDENT_ENSEMBLE_MINIMAL_TEXT_LENGTH_OPTION)


# USER-VARIABLE: LANGIDENT_ENSEMBLE_WEIGHT_LB_IMPRESSO_OPTION
# Option to specify the weight for the Impresso FastText model in language identification.
#
# This variable sets the weight assigned to the Impresso FastText model when scoring
# languages during the language identification process.
LANGIDENT_ENSEMBLE_WEIGHT_LB_IMPRESSO_OPTION ?= 3
  $(call log.debug, LANGIDENT_ENSEMBLE_WEIGHT_LB_IMPRESSO_OPTION)


# USER-VARIABLE: LANGIDENT_ENSEMBLE_MINIMAL_VOTING_SCORE_OPTION
# Option to specify the minimal voting score for language identification.
#
# This variable sets the minimum score required for a language to be considered as a
# valid identification in the language identification process.
LANGIDENT_ENSEMBLE_MINIMAL_VOTING_SCORE_OPTION ?= 0.5
  $(call log.debug, LANGIDENT_ENSEMBLE_MINIMAL_VOTING_SCORE_OPTION)


# USER-VARIABLE: LANGIDENT_ENSEMBLE_THRESHOLD_CONFIDENCE_ORIG_LG_OPTION
# Confidence threshold for trusting original language metadata.
LANGIDENT_ENSEMBLE_THRESHOLD_CONFIDENCE_ORIG_LG_OPTION ?= 0.75
  $(call log.debug, LANGIDENT_ENSEMBLE_THRESHOLD_CONFIDENCE_ORIG_LG_OPTION)


# USER-VARIABLE: LANGIDENT_ENSEMBLE_DOMINANT_LANGUAGE_THRESHOLD_OPTION
# Dominance ratio threshold above which non-dominant languages are penalized.
LANGIDENT_ENSEMBLE_DOMINANT_LANGUAGE_THRESHOLD_OPTION ?= 0.9
  $(call log.debug, LANGIDENT_ENSEMBLE_DOMINANT_LANGUAGE_THRESHOLD_OPTION)


# USER-VARIABLE: LANGIDENT_ENSEMBLE_MINIMAL_LID_PROBABILITY_OPTION
# Minimal probability for a LID decision to be considered a vote in ensemble stage.
LANGIDENT_ENSEMBLE_MINIMAL_LID_PROBABILITY_OPTION ?= 0.5
  $(call log.debug, LANGIDENT_ENSEMBLE_MINIMAL_LID_PROBABILITY_OPTION)


# USER-VARIABLE: LANGIDENT_VALIDATE_OPTION
# Option to enable JSON schema validation for ensemble output.
#
# Set to --validate to enable validation against impresso schema, or leave empty to disable.
LANGIDENT_VALIDATE_OPTION ?=
  $(call log.debug, LANGIDENT_VALIDATE_OPTION)


# USER-VARIABLE: LANGIDENT_ADMISSIBLE_LANGUAGES_OPTION
# Option to specify admissible languages for ensemble decisions.
#
# Space-separated list of language codes to restrict ensemble decisions to, or leave empty for no restrictions.
LANGIDENT_ADMISSIBLE_LANGUAGES_OPTION ?=
  $(call log.debug, LANGIDENT_ADMISSIBLE_LANGUAGES_OPTION)


# USER-VARIABLE: LANGIDENT_ENSEMBLE_EXCLUDE_LB_OPTION
# Option to specify newspapers that should exclude Luxembourgish language predictions in the ensemble stage.
#
# Space-separated list of newspaper acronym prefixes, or leave empty for no exclusions.
LANGIDENT_ENSEMBLE_EXCLUDE_LB_OPTION ?=
  $(call log.debug, LANGIDENT_ENSEMBLE_EXCLUDE_LB_OPTION)


# === USER-CONFIGURABLE VARIABLES (OCR Quality Assessment) ====================

# USER-VARIABLE: LANGIDENT_OCRQA_OPTION
# Option to enable OCR quality assessment using impresso_pipelines.ocrqa
#
# Set to --ocrqa to enable OCR QA, or leave empty to disable.
LANGIDENT_OCRQA_OPTION ?=
  $(call log.debug, LANGIDENT_OCRQA_OPTION)


# USER-VARIABLE: LANGIDENT_OCRQA_REPO_OPTION
# Option to specify the Hugging Face repository for OCR QA models.
#
# Example: impresso-project/OCR-quality-assessment-unigram
LANGIDENT_OCRQA_REPO_OPTION ?=
  $(call log.debug, LANGIDENT_OCRQA_REPO_OPTION)


# USER-VARIABLE: LANGIDENT_OCRQA_VERSION_OPTION
# Option to specify the version/revision of OCR QA models (branch, tag, or commit hash).
#
# Example: main, v2.0.0, or a commit hash
LANGIDENT_OCRQA_VERSION_OPTION ?=
  $(call log.debug, LANGIDENT_OCRQA_VERSION_OPTION)


# USER-VARIABLE: LANGIDENT_LOCAL_FILES_ONLY_OPTION
# Option to load Hugging Face-backed Stage 1 model assets from local files only.
#
# Set to --local-files-only to enable local-files-only loading when supported by the
# downstream impresso_pipelines package, or leave empty to disable.
LANGIDENT_LOCAL_FILES_ONLY_OPTION ?= --local-files-only
  $(call log.debug, LANGIDENT_LOCAL_FILES_ONLY_OPTION)


# === USER-CONFIGURABLE VARIABLES (Work-In-Progress Management) ===============

# USER-VARIABLE: LANGIDENT_WIP_MAX_AGE
# Maximum age in hours for WIP files before considering them stale.
#
# If a WIP file is older than this value, it will be removed and processing can proceed.
# Can be fractional (e.g., 0.1 for 6 minutes, useful for testing).
# Default: 1 hour
LANGIDENT_WIP_MAX_AGE ?= 1
  $(call log.debug, LANGIDENT_WIP_MAX_AGE)


# USER-VARIABLE: LANGIDENT_UPLOAD_IF_NEWER_OPTION
# Option to control S3 upload behavior based on timestamps.
#
# Set to --upload-if-newer to upload only if local timestamp is newer than S3,
# or leave empty to skip upload (file metadata only will be updated).
# Note: Without --force-write, files are not uploaded to S3 by default.
# This is useful when you want to update S3 when local files have changed without
# forcing overwrite of content-wise unchanged files.
# LANGIDENT_UPLOAD_IF_NEWER_OPTION ?= --upload-if-newer
LANGIDENT_UPLOAD_IF_NEWER_OPTION ?=
  $(call log.debug, LANGIDENT_UPLOAD_IF_NEWER_OPTION)


# USER-VARIABLE: LANGIDENT_FORCE_UPLOAD_STAGE1_OPTION
# Option to force upload of Stage 1 files even if S3 version is newer.
#
# DANGER: Set to --force-overwrite to always upload locally-computed files to S3,
# overwriting any existing S3 version regardless of timestamp. Use this when you
# need to guarantee that a freshly-computed Stage 1 result replaces the S3 version.
# Default: empty (no forced upload). Only enable in controlled single-machine scenarios
# or when you explicitly want to overwrite distributed results.
# LANGIDENT_FORCE_UPLOAD_STAGE1_OPTION ?= --force-overwrite
LANGIDENT_FORCE_UPLOAD_STAGE1_OPTION ?=
  $(call log.debug, LANGIDENT_FORCE_UPLOAD_STAGE1_OPTION)


# USER-VARIABLE: LANGIDENT_FORCE_UPLOAD_STAGE2_OPTION
# Option to force upload of Stage 2 statistics files even if S3 output exists.
#
# stats.json is a newspaper-level aggregate over all Stage 1 year files. When a
# missing Stage 1 year is created later, the existing S3 stats.json is stale even
# though it exists. Default to forced replacement for Stage 2 so the explicit
# statistics stage can recompute and upload the aggregate after Stage 1 changes.
LANGIDENT_FORCE_UPLOAD_STAGE2_OPTION ?= --force-overwrite
  $(call log.debug, LANGIDENT_FORCE_UPLOAD_STAGE2_OPTION)


# USER-VARIABLE: LANGIDENT_FORCE_UPLOAD_STAGE3_OPTION
# Option to force upload of Stage 3 ensemble files even if S3 version is newer.
#
# DANGER: Set to --force-overwrite to always upload locally-computed ensemble results.
# Default: empty (no forced upload). Only enable when you explicitly want to replace
# the S3 ensemble files with freshly-computed decisions.
# LANGIDENT_FORCE_UPLOAD_STAGE3_OPTION ?= --force-overwrite
LANGIDENT_FORCE_UPLOAD_STAGE3_OPTION ?=
  $(call log.debug, LANGIDENT_FORCE_UPLOAD_STAGE3_OPTION)


# === INTERNAL COMPUTED VARIABLES ==============================================

# Conditional format option based on USE_CANONICAL
ifeq ($(USE_CANONICAL),1)

# VARIABLE: LANGIDENT_FORMAT_OPTION
# Format option for language identification processing.
LANGIDENT_FORMAT_OPTION := --format=canonical
  $(call log.debug, LANGIDENT_FORMAT_OPTION)

else

# VARIABLE: LANGIDENT_FORMAT_OPTION
# Format option for language identification processing.
LANGIDENT_FORMAT_OPTION := --format=rebuilt
  $(call log.debug, LANGIDENT_FORMAT_OPTION)

endif


# VARIABLE: LANGIDENT_WIP_FORCE_STAGE1
# Internal flag to force WIP acquisition when stage 1 force-upload is enabled.
ifneq ($(LANGIDENT_FORCE_UPLOAD_STAGE1_OPTION),)
LANGIDENT_WIP_FORCE_STAGE1 := --force
else
LANGIDENT_WIP_FORCE_STAGE1 :=
endif
  $(call log.debug, LANGIDENT_WIP_FORCE_STAGE1)


# VARIABLE: LANGIDENT_WIP_FORCE_STAGE2
# Internal flag to force WIP acquisition when stage 2 force-upload is enabled.
ifneq ($(LANGIDENT_FORCE_UPLOAD_STAGE2_OPTION),)
LANGIDENT_WIP_FORCE_STAGE2 := --force
else
LANGIDENT_WIP_FORCE_STAGE2 :=
endif
  $(call log.debug, LANGIDENT_WIP_FORCE_STAGE2)


# VARIABLE: LANGIDENT_WIP_FORCE_STAGE3
# Internal flag to force WIP acquisition when stage 3 force-upload is enabled.
ifneq ($(LANGIDENT_FORCE_UPLOAD_STAGE3_OPTION),)
LANGIDENT_WIP_FORCE_STAGE3 := --force
else
LANGIDENT_WIP_FORCE_STAGE3 :=
endif
  $(call log.debug, LANGIDENT_WIP_FORCE_STAGE3)


# === PATH TRANSFORMATION FUNCTIONS ============================================

# FUNCTION: LocalRebuiltToLangidentStage1File
# Converts a local rebuilt stamp file name to a local langident stage1 file name.
#
# Rebuilt stamps match S3 file names exactly (no suffix).
define LocalRebuiltToLangidentStage1File
$(1:$(LOCAL_PATH_REBUILT)/%.jsonl.bz2=$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2)
endef


# FUNCTION: LocalCanonicalInputStampToLangidentSystemsFile
# Converts a canonical pages/audio stamp file name to a local langident stage1 file name.
#
# Canonical stamps have hard-coded .stamp suffix for yearly directories.
define LocalCanonicalInputStampToLangidentSystemsFile
$(patsubst $(LOCAL_PATH_CANONICAL_AUDIOS)/%.stamp,$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2,$(patsubst $(LOCAL_PATH_CANONICAL_PAGES)/%.stamp,$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2,$(1)))
endef

# FUNCTION: CanonicalInputToIssuesPath
# Converts a canonical pages/audio path to the corresponding issues metadata path.
#
# Example: build.d/112-canonical-final/BL/AATA/pages/AATA-1846 -> build.d/112-canonical-final/BL/AATA/issues/AATA-1846-issues.jsonl.bz2
define CanonicalInputToIssuesPath
$(subst /audios/,/issues/,$(subst /pages/,/issues/,$(1)))-issues.jsonl.bz2
endef

# FUNCTION: CanonicalInputKindFromPath
# Resolves canonical input kind from a local canonical stamp path.
define CanonicalInputKindFromPath
$(if $(findstring /audios/,$(1)),audios,pages)
endef


# FUNCTION: LocalLangIdentSystemsToStatisticsFile
# Converts a local langident systems file name to a local langident statistics file name.
#
# Takes any systems .jsonl.bz2 file and maps it to the stats.json file in the same directory.
define LocalLangIdentSystemsToStatisticsFile
$(dir $(1))stats.json
endef

# FUNCTION: LocalCanonicalStampToLangidentStatsFile
# Converts a canonical stamp file name to a local langident stats file name.
# E.g. LOCAL_PATH_CANONICAL_PAGES = build.d/112-canonical-final/SNL/EDA/pages
# E.g. LOCAL_PATH_LANGIDENT_STAGE1 = build.d/115-canonical-processed-final/langident/langident-lid_stage1-ensemble_multilingual_v2-0-2/SNL/EDA
# E.g. build.d/112-canonical-final/SNL/EDA/pages/{EDA-1843}.stamp -> build.d/115-canonical-processed-final/langident/langident-lid_stage1-ensemble_multilingual_v2-0-2/SNL/EDA/stats.json
define LocalCanonicalStampToLangidentStatsFile
$(1:$(LOCAL_PATH_CANONICAL_PAGES)/%.stamp=$(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json)
endef


# FUNCTION: LocalLangIdentSystemsToEnsembleFile
# Converts a local langident systems file name to a local langident ensemble file name.
#
# Takes systems file path and changes stage1 directory to final output directory.
define LocalLangIdentSystemsToEnsembleFile
$(1:$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2=$(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2)
endef

# FUNCTION: LocalLangIdentSystemsToDiagnosticsFile
# Converts a local langident systems file name to a local langident diagnostics file name.
#
# Takes systems file path and changes stage1 directory to final output directory.
define LocalLangIdentSystemsToDiagnosticsFile
$(1:$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2=$(LOCAL_PATH_LANGIDENT)/%.diagnostics.json)
endef



# === COMPUTED FILE LISTS ======================================================

# VARIABLE: LOCAL_LANGIDENT_SYSTEMS_FILES
# Stores the list of language identification stage1 files based on rebuilt or canonical stamp files.
ifeq ($(USE_CANONICAL),1)
LOCAL_LANGIDENT_SYSTEMS_FILES := \
    $(call LocalCanonicalInputStampToLangidentSystemsFile,$(LOCAL_CANONICAL_INPUT_STAMP_FILE_LIST))
else
LOCAL_LANGIDENT_SYSTEMS_FILES := \
    $(call LocalRebuiltToLangidentStage1File,$(LOCAL_REBUILT_STAMP_FILES))
endif

  $(call log.debug,LOCAL_LANGIDENT_SYSTEMS_FILES)



# VARIABLE: LOCAL_LANGIDENT_STATISTICS_FILES
# Stores the list of langident stage1b statistics files based on stage1 files.
LOCAL_LANGIDENT_STATISTICS_FILES := \
    $(if $(strip $(LOCAL_LANGIDENT_SYSTEMS_FILES)),$(sort $(call LocalLangIdentSystemsToStatisticsFile,$(LOCAL_LANGIDENT_SYSTEMS_FILES))))

  $(call log.debug, LOCAL_LANGIDENT_STATISTICS_FILES)


# VARIABLE: LOCAL_LANGIDENT_ENSEMBLE_FILES
# Stores the list of primary final langident ensemble files based on systems files.
#
# Transforms systems files from LOCAL_PATH_LANGIDENT_STAGE1 to LOCAL_PATH_LANGIDENT.
# The matching %.diagnostics.json file is generated and uploaded as a side effect
# of the corresponding %.jsonl.bz2 recipe, but is not tracked as an independent
# Make target.
#
# Tradeoff:
# If a diagnostics file is deleted directly on S3 while the matching JSONL file
# still exists and is considered up to date, Make will not notice and rebuild
# that diagnostics file automatically. This is intentional here because the
# ensemble recipe assumes the primary target is the JSONL output; tracking
# diagnostics as a separate target causes incorrect multi-target scheduling.
LOCAL_LANGIDENT_ENSEMBLE_FILES := \
	$(call LocalLangIdentSystemsToEnsembleFile,$(LOCAL_LANGIDENT_SYSTEMS_FILES))

  $(call log.debug, LOCAL_LANGIDENT_ENSEMBLE_FILES)


# === MAIN PROCESSING PIPELINE =================================================

# TARGET: langident-target
#: Processes language identification tasks in three sequential stages.
#
# Overall processing target for language identification.
langident-target : langident-ensemble-target

.PHONY: langident-target

help-processing::
	@echo "LANGIDENT PROCESSING:"
	@echo "  langident-target            # Run all language-identification stages"
	@echo "  langident-systems-target    # Run stage 1 system-level language identification"
	@echo "  langident-statistics-target # Compute language-identification statistics"
	@echo "  langident-ensemble-target   # Build final language-identification ensemble"
	@echo ""
	@echo "LANGIDENT VARIABLES:"
	@echo "  USE_CANONICAL=$(USE_CANONICAL)"
	@echo "  LANGIDENT_LOGGING_LEVEL=$(LANGIDENT_LOGGING_LEVEL)"
	@echo "  LANGIDENT_VALIDATE_OPTION=$(LANGIDENT_VALIDATE_OPTION)"
	@echo "  LANGIDENT_WIP_MAX_AGE=$(LANGIDENT_WIP_MAX_AGE)"
	@echo "  LANGIDENT_UPLOAD_IF_NEWER_OPTION=$(LANGIDENT_UPLOAD_IF_NEWER_OPTION)"


# TARGET: langident-systems-target
# Apply different language identification systems.
#
# Uses recursive make to recompute file lists after sync creates new stamp files.
ifeq ($(USE_CANONICAL),1)

langident-systems-target : sync-canonical
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) langident-systems-files-target

else

langident-systems-target : $(LOCAL_REBUILT_SYNC_STAMP_FILE)
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) langident-systems-files-target

endif

.PHONY: langident-systems-target


# TARGET: langident-systems-files-target
# Internal target that builds the actual language identification system files.
#
# This is called recursively after sync to ensure stamp files are available.
langident-systems-files-target : $(LOCAL_LANGIDENT_SYSTEMS_FILES)

.PHONY: langident-systems-files-target


# TARGET: langident-statistics-target
# Collect language identification statistics from all stage1 files.
#
# This target generates newspaper-level statistics (dominant language, language
# distributions, confidence metrics) by aggregating data from all stage1 files
# for the current newspaper.
#
# Dependencies:
#   - langident-systems-target: Ensures all stage1 files are created first
#
# Uses recursive make to ensure stage1 output exists before building statistics.
#
# Output:
#   - $(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json: Newspaper statistics file
langident-statistics-target : langident-systems-target
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) langident-statistics-files-target

.PHONY: langident-statistics-target


# TARGET: langident-statistics-files-target
# Internal target that builds the actual statistics file.
#
# This is called recursively after systems stage to ensure files are available.
#
langident-statistics-files-target : $(LOCAL_LANGIDENT_STATISTICS_FILES)

.PHONY: langident-statistics-files-target


# TARGET: langident-ensemble-target
# Generate final language identification decisions using ensemble voting.
#
# This target creates the final output files by combining predictions from
# multiple LID systems using ensemble decision-making algorithms.
#
# Dependencies:
#   - langident-statistics-target: Ensures statistics are computed first
#
# Uses recursive make to ensure statistics exist before building ensemble files.
#
# Each ensemble file depends on (via file-level rule below):
#   - $(LOCAL_PATH_LANGIDENT_STAGE1)/NEWSPAPER-YEAR.jsonl.bz2: Stage1 predictions
#   - $(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json: Newspaper statistics
#
# The explicit dependency on langident-statistics-target ensures that when
# running with parallel jobs, the statistics stage completes before any ensemble
# processing begins, preventing race conditions.
langident-ensemble-target : langident-statistics-target
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) langident-ensemble-files-target

.PHONY: langident-ensemble-target


# TARGET: langident-ensemble-files-target
# Internal target that builds the actual ensemble files.
#
# This is called recursively after statistics stage to ensure files are available.
langident-ensemble-files-target : $(LOCAL_LANGIDENT_ENSEMBLE_FILES)

.PHONY: langident-ensemble-files-target


# === STAGE 1: SYSTEMS FILE RULES ==============================================

ifeq ($(USE_CANONICAL),1)

# FILE-RULE: $(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2 (canonical version)
#: Rule to process a single newspaper from canonical format.
$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2: $(LOCAL_PATH_CANONICAL_PAGES)/%.stamp
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	python3 -m impresso_cookbook.manage_s3_wip acquire \
		--s3-target $(call LocalToS3,$@) \
		--wip-max-age $(LANGIDENT_WIP_MAX_AGE) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
		--local-target $@ \
		--files $@ $@.log.gz \
		$(LANGIDENT_WIP_FORCE_STAGE1) \
	|| { status=$$?; case $$status in 2|3) exit 0 ;; *) exit $$status ;; esac; } \
	&& \
	python3 lib/impresso_langident_systems.py \
		$(LANGIDENT_FORMAT_OPTION) \
		--canonical-input-kind $(call CanonicalInputKindFromPath,$<) \
		--infile $(call LocalToS3,$(basename $<)) \
		--issue-file $(call LocalToS3,$(call CanonicalInputToIssuesPath,$(basename $<))) \
		--outfile $@ \
		--lids $(LANGIDENT_SYSTEMS_LIDS_OPTION) \
		--impresso-ft $(LANGIDENT_SYSTEMS_IMPPRESSO_FASTTEXT_MODEL_OPTION) \
		--wp-ft $(LANGIDENT_SYSTEMS_WP_FASTTEXT_MODEL_OPTION) \
		--minimal-text-length $(LANGIDENT_SYSTEMS_MINIMAL_TEXT_LENGTH_OPTION) \
		--alphabetical-ratio-threshold $(LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION) \
		--round-ndigits $(LANGIDENT_ROUND_NDIGITS_OPTION) \
		--git-describe $(GIT_VERSION) \
		--log-file $@.log.gz \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
		$(LANGIDENT_LOCAL_FILES_ONLY_OPTION) \
		$(LANGIDENT_OCRQA_OPTION) \
		$(if $(LANGIDENT_OCRQA_REPO_OPTION),--ocrqa-repo $(LANGIDENT_OCRQA_REPO_OPTION),) \
		$(if $(LANGIDENT_OCRQA_VERSION_OPTION),--ocrqa-version $(LANGIDENT_OCRQA_VERSION_OPTION),) \
	&& python3 -m impresso_cookbook.local_to_s3 \
		--set-timestamp --log-level $(LANGIDENT_LOGGING_LEVEL) \
		$(LANGIDENT_FORCE_UPLOAD_STAGE1_OPTION) \
		$@ $(call LocalToS3,$@) \
		$@.log.gz $(call LocalToS3,$@).log.gz \
	&& python3 -m impresso_cookbook.manage_s3_wip release \
		--s3-target $(call LocalToS3,$@) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
	|| { rm -vf $@ ; \
	     python3 -m impresso_cookbook.manage_s3_wip release \
	         --s3-target $(call LocalToS3,$@) \
	         --log-level $(LANGIDENT_LOGGING_LEVEL) || true ; \
	     exit 1 ; }

# FILE-RULE: $(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2 (canonical audio version)
#: Rule to process a single radio source from canonical audio format.
$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2: $(LOCAL_PATH_CANONICAL_AUDIOS)/%.stamp
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	python3 -m impresso_cookbook.manage_s3_wip acquire \
		--s3-target $(call LocalToS3,$@) \
		--wip-max-age $(LANGIDENT_WIP_MAX_AGE) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
		--local-target $@ \
		--files $@ $@.log.gz \
		$(LANGIDENT_WIP_FORCE_STAGE1) \
	|| { status=$$?; case $$status in 2|3) exit 0 ;; *) exit $$status ;; esac; } \
	&& \
	python3 lib/impresso_langident_systems.py \
		$(LANGIDENT_FORMAT_OPTION) \
		--canonical-input-kind $(call CanonicalInputKindFromPath,$<) \
		--infile $(call LocalToS3,$(basename $<)) \
		--issue-file $(call LocalToS3,$(call CanonicalInputToIssuesPath,$(basename $<))) \
		--outfile $@ \
		--lids $(LANGIDENT_SYSTEMS_LIDS_OPTION) \
		--impresso-ft $(LANGIDENT_SYSTEMS_IMPPRESSO_FASTTEXT_MODEL_OPTION) \
		--wp-ft $(LANGIDENT_SYSTEMS_WP_FASTTEXT_MODEL_OPTION) \
		--minimal-text-length $(LANGIDENT_SYSTEMS_MINIMAL_TEXT_LENGTH_OPTION) \
		--alphabetical-ratio-threshold $(LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION) \
		--round-ndigits $(LANGIDENT_ROUND_NDIGITS_OPTION) \
		--git-describe $(GIT_VERSION) \
		--log-file $@.log.gz \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
		$(LANGIDENT_LOCAL_FILES_ONLY_OPTION) \
		$(LANGIDENT_OCRQA_OPTION) \
		$(if $(LANGIDENT_OCRQA_REPO_OPTION),--ocrqa-repo $(LANGIDENT_OCRQA_REPO_OPTION),) \
		$(if $(LANGIDENT_OCRQA_VERSION_OPTION),--ocrqa-version $(LANGIDENT_OCRQA_VERSION_OPTION),) \
	&& python3 -m impresso_cookbook.local_to_s3 \
		--set-timestamp --log-level $(LANGIDENT_LOGGING_LEVEL) \
		$(LANGIDENT_FORCE_UPLOAD_STAGE1_OPTION) \
		$@ $(call LocalToS3,$@) \
		$@.log.gz $(call LocalToS3,$@).log.gz \
	&& python3 -m impresso_cookbook.manage_s3_wip release \
		--s3-target $(call LocalToS3,$@) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
	|| { rm -vf $@ ; \
	     python3 -m impresso_cookbook.manage_s3_wip release \
	         --s3-target $(call LocalToS3,$@) \
	         --log-level $(LANGIDENT_LOGGING_LEVEL) || true ; \
	     exit 1 ; }

else

# FILE-RULE: $(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2 (rebuilt version)
#: Rule to process a single newspaper from rebuilt format.
#
# Rebuilt stamps match S3 file names exactly (no suffix to strip).
$(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2: $(LOCAL_PATH_REBUILT)/%.jsonl.bz2
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) && \
	python3 -m impresso_cookbook.manage_s3_wip acquire \
		--s3-target $(call LocalToS3,$@) \
		--wip-max-age $(LANGIDENT_WIP_MAX_AGE) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
		--local-target $@ \
		--files $@ $@.log.gz \
		$(LANGIDENT_WIP_FORCE_STAGE1) \
	|| { status=$$?; case $$status in 2|3) exit 0 ;; *) exit $$status ;; esac; } \
	&& \
	python3 lib/impresso_langident_systems.py \
		$(LANGIDENT_FORMAT_OPTION) \
		--infile $(call LocalToS3,$<) \
		--outfile $@ \
		--lids $(LANGIDENT_SYSTEMS_LIDS_OPTION) \
		--impresso-ft $(LANGIDENT_SYSTEMS_IMPPRESSO_FASTTEXT_MODEL_OPTION) \
		--wp-ft $(LANGIDENT_SYSTEMS_WP_FASTTEXT_MODEL_OPTION) \
		--minimal-text-length $(LANGIDENT_SYSTEMS_MINIMAL_TEXT_LENGTH_OPTION) \
		--alphabetical-ratio-threshold $(LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION) \
		--round-ndigits $(LANGIDENT_ROUND_NDIGITS_OPTION) \
		--git-describe $(GIT_VERSION) \
		--log-file $@.log.gz \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
		$(LANGIDENT_LOCAL_FILES_ONLY_OPTION) \
		$(LANGIDENT_OCRQA_OPTION) \
		$(if $(LANGIDENT_OCRQA_REPO_OPTION),--ocrqa-repo $(LANGIDENT_OCRQA_REPO_OPTION),) \
		$(if $(LANGIDENT_OCRQA_VERSION_OPTION),--ocrqa-version $(LANGIDENT_OCRQA_VERSION_OPTION),) \
	&& python3 -m impresso_cookbook.local_to_s3 \
		--set-timestamp --log-level $(LANGIDENT_LOGGING_LEVEL) \
		--keep-timestamp-only $(LANGIDENT_FORCE_UPLOAD_STAGE1_OPTION) \
		$@ $(call LocalToS3,$@) \
		$@.log.gz $(call LocalToS3,$@).log.gz \
	&& python3 -m impresso_cookbook.manage_s3_wip release \
		--s3-target $(call LocalToS3,$@) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
	|| { rm -vf $@ ; \
	     python3 -m impresso_cookbook.manage_s3_wip release \
	         --s3-target $(call LocalToS3,$@) \
	         --log-level $(LANGIDENT_LOGGING_LEVEL) || true ; \
	     exit 1 ; }

endif


# === STAGE 2: STATISTICS FILE RULES ===========================================

# FILE-RULE: $(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json
# Rule to generate statistics for a single newspaper from systems results.
#
# This file can be created by synchronization as the local mirror/stamp for
# S3 stats.json. The phony langident-statistics-files-target forces this rule
# when the statistics stage is explicitly reached so newly-created stage1 years
# are incorporated even if stats.json already exists.
# Phony prerequisite: make the newspaper-level aggregate refresh whenever the
# stats target is considered, without forcing stage1 year files themselves.
.PHONY: FORCE_LANGIDENT_STATISTICS

$(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json: $(LOCAL_LANGIDENT_SYSTEMS_FILES) FORCE_LANGIDENT_STATISTICS
	$(MAKE_SILENCE_RECIPE) \
	python3 scripts/check_stage1_newspaper_ready.py \
		--wip-max-age $(LANGIDENT_WIP_MAX_AGE) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
		--local-target $@ \
		$(foreach file,$(LOCAL_LANGIDENT_SYSTEMS_FILES),--stage1-output $(call LocalToS3,$(file))) \
	|| { status=$$?; case $$status in 1) exit 0 ;; *) exit $$status ;; esac; } \
	&& \
	python3 -m impresso_cookbook.manage_s3_wip acquire \
		--s3-target $(call LocalToS3,$@) \
		--wip-max-age $(LANGIDENT_WIP_MAX_AGE) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
		--local-target $@ \
		--files $@ $(dir $@)stats.json.log.gz \
		$(LANGIDENT_WIP_FORCE_STAGE2) \
	|| { status=$$?; case $$status in 2|3) exit 0 ;; *) exit $$status ;; esac; } \
	&& \
	mkdir -p $(dir $@) && \
	python3 lib/newspaper_statistics.py \
		--newspaper $(notdir $(NEWSPAPER)) \
		--lids $(LANGIDENT_SYSTEMS_LIDS_OPTION) \
		--boosted-lids orig_lg impresso_ft \
		--minimal-text-length $(LANGIDENT_STATISTICS_MINIMAL_TEXT_LENGTH_OPTION) \
		--boost-factor $(LANGIDENT_STATISTICS_BOOST_FACTOR_OPTION) \
		--minimal-vote-score $(LANGIDENT_STATISTICS_MINIMAL_VOTE_SCORE_OPTION) \
		--minimal-lid-probability $(LANGIDENT_SYSTEMS_MINIMAL_LID_PROBABILITY_OPTION) \
		--git-describe $(GIT_VERSION) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
		--log-file $(dir $@)stats.json.log.gz \
		--outfile $(dir $@)stats.json \
		$(call LocalToS3,$(dir $<)) \
	&& \
	python3 -m impresso_cookbook.local_to_s3 \
		--set-timestamp --log-level $(LANGIDENT_LOGGING_LEVEL) \
		--keep-timestamp-only $(LANGIDENT_UPLOAD_IF_NEWER_OPTION) \
		$(LANGIDENT_FORCE_UPLOAD_STAGE2_OPTION) \
		$(dir $@)stats.json $(call LocalToS3,$(dir $@)stats.json) \
		$(dir $@)stats.json.log.gz $(call LocalToS3,$(dir $@)stats.json.log.gz) \
	&& python3 -m impresso_cookbook.manage_s3_wip release \
		--s3-target $(call LocalToS3,$@) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
	|| { rm -vf $@ ; \
		python3 -m impresso_cookbook.manage_s3_wip release \
			--s3-target $(call LocalToS3,$@) \
			--log-level $(LANGIDENT_LOGGING_LEVEL) || true ; \
		rm -vf $(dir $@)stats.json.log.gz ; \
		exit 1 ; }


# === STAGE 3: ENSEMBLE FILE RULES =============================================

# PATTERN-FILE-RULE: $(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2
#: Rule to build ensemble decisions with diagnostics.
#
# Each ensemble file depends on:
#   1. Its corresponding Stage 1a file (with predictions from all LID systems)
#   2. The newspaper-level stats.json file (Stage 1b statistics)
#
# Note: File stamps match S3 names exactly (no suffix), so stats.json is just stats.json.
# The matching %.diagnostics.json file is generated and uploaded by this same
# recipe as a side effect of building the primary %.jsonl.bz2 target. It is not
# declared as an independent target because this recipe derives filenames from
# $@ and therefore assumes that $@ is the JSONL output. Listing diagnostics as
# a primary target can make Make invoke this recipe with $@ set to the
# diagnostics file, which breaks the upload/output path logic.
$(LOCAL_PATH_LANGIDENT)/%.jsonl.bz2: $(LOCAL_PATH_LANGIDENT_STAGE1)/%.jsonl.bz2 $(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json
	$(MAKE_SILENCE_RECIPE) \
	mkdir -p $(@D) \
  && \
	python3 scripts/check_ensemble_year_ready.py \
		--stage1-output $(call LocalToS3,$<) \
		--stats-output $(call LocalToS3,$(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json) \
		--wip-max-age $(LANGIDENT_WIP_MAX_AGE) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
		--local-target $@ \
	|| { status=$$?; case $$status in 1) exit 0 ;; *) exit $$status ;; esac; } \
	&& \
	python3 -m impresso_cookbook.manage_s3_wip acquire \
		--s3-target $(call LocalToS3,$@) \
		--wip-max-age $(LANGIDENT_WIP_MAX_AGE) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
		--local-target $@ \
		--files $@ $@.log.gz $(patsubst %.jsonl.bz2,%.diagnostics.json,$@) \
		$(LANGIDENT_WIP_FORCE_STAGE3) \
	|| { status=$$?; case $$status in 2|3) exit 0 ;; *) exit $$status ;; esac; } \
	&& \
	python3 lib/impresso_ensemble_lid.py \
    --lids $(LANGIDENT_SYSTEMS_LIDS_OPTION) \
    --weight-lb-impresso-ft $(LANGIDENT_ENSEMBLE_WEIGHT_LB_IMPRESSO_OPTION) \
    --minimal-lid-probability $(LANGIDENT_ENSEMBLE_MINIMAL_LID_PROBABILITY_OPTION) \
    --minimal-voting-score $(LANGIDENT_ENSEMBLE_MINIMAL_VOTING_SCORE_OPTION) \
    --minimal-text-length $(LANGIDENT_ENSEMBLE_MINIMAL_TEXT_LENGTH_OPTION) \
    --threshold_confidence_orig_lg $(LANGIDENT_ENSEMBLE_THRESHOLD_CONFIDENCE_ORIG_LG_OPTION) \
    --newspaper-stats-filename $(call LocalToS3,$(LOCAL_PATH_LANGIDENT_STAGE1)/stats.json) \
    --git-describe $(GIT_VERSION) \
    --alphabetical-ratio-threshold  $(LANGIDENT_SYSTEMS_ALPHABETICAL_THRESHOLD_OPTION) \
    --dominant-language-threshold $(LANGIDENT_ENSEMBLE_DOMINANT_LANGUAGE_THRESHOLD_OPTION) \
    --diagnostics-json $(patsubst %.jsonl.bz2,%.diagnostics.json,$@) \
    --infile $(call LocalToS3,$<) \
    --outfile $@ \
    --log-level $(LANGIDENT_LOGGING_LEVEL) \
    --log-file $@.log.gz \
    $(LANGIDENT_VALIDATE_OPTION) \
    $(if $(LANGIDENT_ADMISSIBLE_LANGUAGES_OPTION),--admissible-languages $(LANGIDENT_ADMISSIBLE_LANGUAGES_OPTION),) \
    $(if $(LANGIDENT_ENSEMBLE_EXCLUDE_LB_OPTION),--exclude-lb $(LANGIDENT_ENSEMBLE_EXCLUDE_LB_OPTION),) \
  && \
	python3 -m impresso_cookbook.local_to_s3 \
		--set-timestamp $(LANGIDENT_UPLOAD_IF_NEWER_OPTION) \
		$(LANGIDENT_FORCE_UPLOAD_STAGE3_OPTION) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
		$@    $(call LocalToS3,$@) \
		$@.log.gz    $(call LocalToS3,$@).log.gz \
		$(patsubst %.jsonl.bz2,%.diagnostics.json,$@)    $(call LocalToS3,$(patsubst %.jsonl.bz2,%.diagnostics.json,$@)) \
	&& python3 -m impresso_cookbook.manage_s3_wip release \
		--s3-target $(call LocalToS3,$@) \
		--log-level $(LANGIDENT_LOGGING_LEVEL) \
	|| { rm -vf $@ $(patsubst %.jsonl.bz2,%.diagnostics.json,$@) ; \
		python3 -m impresso_cookbook.manage_s3_wip release \
			--s3-target $(call LocalToS3,$@) \
			--log-level $(LANGIDENT_LOGGING_LEVEL) || true ; \
		exit 1 ; }

$(call log.debug, COOKBOOK END INCLUDE: cookbook/processing_langident.mk)
