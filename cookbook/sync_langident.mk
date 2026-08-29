$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sync_langident.mk)

###############################################################################
# SYNC LANGUAGE IDENTIFICATION TARGETS
#
# Targets for synchronizing processed language identification data
# between S3 and local storage.
#
# This module synchronizes two stages of language identification processing:
# 1. Stage 1a/1b (component output) - Individual LID system predictions and newspaper statistics
# 2. Ensemble stage (final output) - Final language identification decisions using voting
#
# PROCESSING FLOW:
# ================
# Stage 1a → Stage 1b → Ensemble Stage
#
# Stage 1a: Individual LID system outputs
#   - Multiple language identification systems (langid, wp_ft, impresso_ft, lingua, etc.)
#     each predict the language for every content item
#   - Output: Per-newspaper-year files with predictions from all systems
#   - Example: WTCH-1828.jsonl.bz2 contains predictions from all LID systems for year 1828
#
# Stage 1b: Newspaper-level aggregation statistics
#   - Aggregates all Stage 1a predictions to compute newspaper-wide language distribution
#   - Assesses confidence in original metadata by comparing with ensemble voting
#   - Determines dominant language(s) for the newspaper
#   - Output: Single stats.json file per newspaper with aggregated statistics
#   - Example: stats.json contains overall language distribution for newspaper WTCH
#
# Ensemble Stage: Final language decisions
#   - Takes Stage 1a predictions (individual systems) and Stage 1b statistics (newspaper distribution)
#   - Applies rule-based voting with weights informed by newspaper-level statistics
#   - Makes final language decision per content item considering:
#     * Agreement among systems
#     * Confidence scores from each system
#     * Dominant language from Stage 1b statistics
#     * Text length and quality
#   - Output: Final LID results plus diagnostics
#   - Example: WTCH-1828.jsonl.bz2 (final) + WTCH-1828.diagnostics.json
#
# PATH STRUCTURE:
# ==============
# The language identification data is organized hierarchically on S3 by:
# - Bucket (different for ensemble output vs component output)
# - Process label ("langident")
# - Run ID (includes task, model, and version)
# - Newspaper identifier
#
# Example path construction for newspaper "BL/WTCH":
#
# Stage 1a/1b (Component Data - LID System Predictions + Newspaper Statistics):
#   S3_BUCKET_LANGIDENT_STAGE1 = "130-component-sandbox"
#   TASK_LANGIDENT_STAGE1 = "lid_stage1"
#   RUN_ID_LANGIDENT_STAGE1 = "langident-lid_stage1-ensemble_multilingual_v2-0-2"
#   
#   S3: s3://130-component-sandbox/langident/langident-lid_stage1-ensemble_multilingual_v2-0-2/BL/WTCH/
#       ├── WTCH-1828.jsonl.bz2          (Stage 1a: predictions from langid, wp_ft, impresso_ft, lingua, etc.)
#       ├── WTCH-1829.jsonl.bz2          (Stage 1a: all system predictions per year)
#       ├── stats.json                   (Stage 1b: newspaper-level statistics for voting)
#       └── ...
#   
#   Local: build.d/130-component-sandbox/langident/langident-lid_stage1-ensemble_multilingual_v2-0-2/BL/WTCH/
#       ├── WTCH-1828.jsonl.bz2          (stamp file for S3 object - same name)
#       ├── WTCH-1829.jsonl.bz2          (stamp file for S3 object - same name)
#       ├── stats.json                   (stamp file for S3 object - same name)
#       └── .last_synced                 (master sync timestamp)
#
# Ensemble Stage (Final Results - Using Stage 1a predictions + Stage 1b statistics):
#   S3_BUCKET_LANGIDENT = "140-processed-data-sandbox"
#   PROCESS_LABEL_LANGIDENT = "langident"
#   TASK_LANGIDENT = "lid"
#   MODEL_ID_LANGIDENT = "ensemble_multilingual"
#   RUN_VERSION_LANGIDENT = "v2-0-2"
#   RUN_ID_LANGIDENT = "langident-lid-ensemble_multilingual_v2-0-2"
#   NEWSPAPER = "BL/WTCH"
#   
#   S3: s3://140-processed-data-sandbox/langident/langident-lid-ensemble_multilingual_v2-0-2/BL/WTCH/
#       ├── WTCH-1828.jsonl.bz2          (Ensemble: final LID decisions informed by stats.json)
#       ├── WTCH-1829.jsonl.bz2          (Ensemble: final decisions per year)
#       ├── WTCH-1828.diagnostics.json   (Ensemble: decision diagnostics and confidence)
#       └── ...
#   
#   Local: build.d/140-processed-data-sandbox/langident/langident-lid-ensemble_multilingual_v2-0-2/BL/WTCH/
#       ├── WTCH-1828.jsonl.bz2          (stamp file for S3 object)
#       ├── WTCH-1829.jsonl.bz2          (stamp file for S3 object)
#       ├── WTCH-1828.diagnostics.json   (stamp file for S3 object)
#       └── .last_synced                 (master sync timestamp)
#
# STAMP FILE NAMING:
# ==================
# File stamps ALWAYS match S3 object names exactly (no suffix):
#   - Example: S3 file "WTCH-1828.jsonl.bz2" → local stamp "WTCH-1828.jsonl.bz2" (zero-byte file)
#   - Example: S3 file "stats.json" → local stamp "stats.json" (zero-byte file)
# 
# Directory stamps (if used) always have .stamp suffix to avoid conflicts with mkdir.
# Master sync: .last_synced file marks completion of full sync operation.
###############################################################################


# VARIABLE: LOCAL_LANGIDENT_SYNC_STAMP_FILE
# Local synchronization stamp file for Ensemble stage output data.
#
# This file serves as a marker indicating whether the Ensemble stage
# language identification data from S3 has been successfully synced to
# local storage.
#
# The Ensemble stage produces final language decisions by combining:
#   - Stage 1a predictions from individual LID systems
#   - Stage 1b newspaper-level statistics (dominant languages, confidence)
#   - Rule-based voting weighted by system confidence
#
# Variable composition:
#   LOCAL_PATH_LANGIDENT = $(BUILD_DIR)/$(PATH_LANGIDENT)
#   PATH_LANGIDENT = $(S3_BUCKET_LANGIDENT)/$(PROCESS_LABEL_LANGIDENT)/$(RUN_ID_LANGIDENT)/$(NEWSPAPER)
#
# Example for NEWSPAPER="BL/WTCH":
#   LOCAL_PATH_LANGIDENT = "build.d/140-processed-data-sandbox/langident/langident-lid-ensemble_multilingual_v2-0-2/BL/WTCH"
#   LOCAL_LANGIDENT_SYNC_STAMP_FILE = "build.d/140-processed-data-sandbox/langident/langident-lid-ensemble_multilingual_v2-0-2/BL/WTCH.last_synced"
LOCAL_LANGIDENT_SYNC_STAMP_FILE := $(LOCAL_PATH_LANGIDENT).last_synced
  $(call log.debug, LOCAL_LANGIDENT_SYNC_STAMP_FILE)


# STAMPED-FILE-RULE: $(LOCAL_PATH_LANGIDENT).last_synced
# Synchronizes Ensemble stage language identification output from S3 to local stamp files.
#
# PURPOSE:
#   Creates local stamp files mirroring the S3 ensemble output structure for Make dependency tracking.
#   The Ensemble stage output contains final language decisions that were made by considering:
#     1. Individual LID system predictions from Stage 1a
#     2. Newspaper-level statistics from Stage 1b (dominant languages, confidence metrics)
#     3. Rule-based voting with weights informed by overall language distribution
#   These stamps enable resumable processing and distributed builds without downloading full data files.
#
# WHAT GETS SYNCHRONIZED:
#   Source (S3): $(S3_PATH_LANGIDENT)
#                s3://$(S3_BUCKET_LANGIDENT)/$(PROCESS_LABEL_LANGIDENT)/$(RUN_ID_LANGIDENT)/$(NEWSPAPER)/
#   
#   Target (Local): $(LOCAL_PATH_LANGIDENT)
#                   $(BUILD_DIR)/$(S3_BUCKET_LANGIDENT)/$(PROCESS_LABEL_LANGIDENT)/$(RUN_ID_LANGIDENT)/$(NEWSPAPER)/
#
# EXAMPLE for NEWSPAPER="BL/WTCH":
#   S3 Source:
#     s3://140-processed-data-sandbox/langident/langident-lid-ensemble_multilingual_v2-0-2/BL/WTCH/
#     ├── WTCH-1828.jsonl.bz2  (final ensemble LID decisions for 1828, using Stage 1b stats)
#     ├── WTCH-1829.jsonl.bz2  (final ensemble LID decisions for 1829)
#     ├── WTCH-1828.diagnostics.json  (decision diagnostics: codes, confidence, voting breakdown)
#     └── ...
#   
#   Local Stamps Created:
#     build.d/140-processed-data-sandbox/langident/langident-lid-ensemble_multilingual_v2-0-2/BL/WTCH/
#     ├── WTCH-1828.jsonl.bz2          (zero-byte timestamp stamp - same name as S3 file)
#     ├── WTCH-1829.jsonl.bz2          (zero-byte timestamp stamp - same name as S3 file)
#     ├── WTCH-1828.diagnostics.json   (zero-byte timestamp stamp - same name as S3 file)
#     └── .last_synced                 (this file - marks sync completion)
#
# STAMP BEHAVIOR:
#   - File-level stamps match S3 object names exactly (no suffix)
#   - Each S3 file gets one local stamp file with the same name
#   - Stamps are zero-byte files with timestamps matching S3 object modification times
#   - Dangling stamps (for deleted S3 objects) are automatically removed
#
# SCRIPT: impresso_cookbook.s3_to_local_stamps
#   --local-dir: Base directory for creating stamp hierarchy
#   --stamp-mode per-file: Create one stamp per S3 file with exact filename
#   --remove-dangling-stamps: Clean up stamps for non-existent S3 objects
#   --logfile: Compressed log of sync operation
# Persistent marker updated after successful synchronization. Used by
# downstream targets for dependency/timestamp tracking. Requesting this marker
# directly only ensures it exists; use sync-langident or sync-langident-final
# to force a fresh S3 query.
$(LOCAL_PATH_LANGIDENT).last_synced:
	$(MAKE) sync-langident-final

# Phony operation: always queries S3 when explicitly requested.
sync-langident-final:
	# Syncing the processed data from $(S3_PATH_LANGIDENT)
	# to $(LOCAL_PATH_LANGIDENT)
	mkdir -p $(dir $(LOCAL_LANGIDENT_SYNC_STAMP_FILE)) && \
	$(PYTHON) -m impresso_cookbook.s3_to_local_stamps \
	   $(S3_PATH_LANGIDENT) \
	   --local-dir $(BUILD_DIR) \
	   --file-extensions jsonl.bz2 json \
	   --stamp-mode per-file \
	   --remove-dangling-stamps \
	   --logfile $(LOCAL_LANGIDENT_SYNC_STAMP_FILE).log.gz \
	   --log-level $(LOGGING_LEVEL) \
	&& \
	touch $(LOCAL_LANGIDENT_SYNC_STAMP_FILE)

# VARIABLE: LOCAL_LANGIDENT_STAGE1_SYNC_STAMP_FILE
# Local synchronization stamp file for Stage 1a/1b component data.
#
# This file serves as a marker indicating whether the Stage 1a and Stage 1b data
# from S3 has been successfully synced to local storage.
#
# Stage 1a produces individual LID system predictions (one file per newspaper-year).
# Stage 1b produces newspaper-level aggregation statistics (one stats.json per newspaper).
#
# The Ensemble stage depends on both:
#   - Stage 1a files: Individual system predictions for each content item
#   - Stage 1b file: Overall language distribution to inform ensemble voting
#
# Variable composition:
#   LOCAL_PATH_LANGIDENT_STAGE1 = $(BUILD_DIR)/$(PATH_LANGIDENT_STAGE1)
#   PATH_LANGIDENT_STAGE1 = $(S3_BUCKET_LANGIDENT_STAGE1)/$(PROCESS_LABEL_LANGIDENT)/$(RUN_ID_LANGIDENT_STAGE1)/$(NEWSPAPER)
#
# Example for NEWSPAPER="BL/WTCH":
#   LOCAL_PATH_LANGIDENT_STAGE1 = "build.d/130-component-sandbox/langident/langident-lid_stage1-ensemble_multilingual_v2-0-2/BL/WTCH"
#   LOCAL_LANGIDENT_STAGE1_SYNC_STAMP_FILE = "build.d/130-component-sandbox/langident/langident-lid_stage1-ensemble_multilingual_v2-0-2/BL/WTCH.last_synced"
LOCAL_LANGIDENT_STAGE1_SYNC_STAMP_FILE := $(LOCAL_PATH_LANGIDENT_STAGE1).last_synced
  $(call log.debug, LOCAL_LANGIDENT_STAGE1_SYNC_STAMP_FILE)



# STAMPED-FILE-RULE: $(LOCAL_PATH_LANGIDENT_STAGE1).last_synced
# Synchronizes Stage 1a/1b component data from S3 to local stamps.
#
# PURPOSE:
#   Creates local stamp files for:
#     - Stage 1a: Individual LID system predictions (langid, wp_ft, impresso_ft, lingua, etc.)
#     - Stage 1b: Newspaper-level aggregation statistics used to inform ensemble decisions
#   
#   The Stage 1b stats.json file contains critical information for the Ensemble stage:
#     * Dominant language(s) for the newspaper
#     * Confidence in original metadata
#     * Overall language distribution across all content items
#     * Per-system performance metrics
#   
#   These stamps enable the Ensemble stage to have proper Make dependencies without
#   downloading the full prediction files.
#
# WHAT GETS SYNCHRONIZED:
#   Source (S3): $(S3_PATH_LANGIDENT_STAGE1)
#                s3://$(S3_BUCKET_LANGIDENT_STAGE1)/$(PROCESS_LABEL_LANGIDENT)/$(RUN_ID_LANGIDENT_STAGE1)/$(NEWSPAPER)/
#   
#   Target (Local): $(LOCAL_PATH_LANGIDENT_STAGE1)
#                   $(BUILD_DIR)/$(S3_BUCKET_LANGIDENT_STAGE1)/$(PROCESS_LABEL_LANGIDENT)/$(RUN_ID_LANGIDENT_STAGE1)/$(NEWSPAPER)/
#
# EXAMPLE for NEWSPAPER="BL/WTCH":
#   S3 Source:
#     s3://130-component-sandbox/langident/langident-lid_stage1-ensemble_multilingual_v2-0-2/BL/WTCH/
#     ├── WTCH-1828.jsonl.bz2    (Stage 1a: all system predictions for each content item in 1828)
#     ├── WTCH-1829.jsonl.bz2    (Stage 1a: all system predictions for 1829)
#     ├── WTCH-1830.jsonl.bz2    (Stage 1a: all system predictions for 1830)
#     ├── stats.json             (Stage 1b: newspaper-wide statistics for ensemble voting)
#     └── ...
#   
#   Local Stamps Created:
#     build.d/130-component-sandbox/langident/langident-lid_stage1-ensemble_multilingual_v2-0-2/BL/WTCH/
#     ├── WTCH-1828.jsonl.bz2          (timestamp stamp - same name as S3 file)
#     ├── WTCH-1829.jsonl.bz2          (timestamp stamp - same name as S3 file)
#     ├── WTCH-1830.jsonl.bz2          (timestamp stamp - same name as S3 file)
#     ├── stats.json                   (timestamp stamp - same name as S3 file)
#     └── .last_synced                 (this file - marks sync completion)
#
# FILE TYPES SYNCHRONIZED:
#   --file-extensions jsonl.bz2 json
#     - .jsonl.bz2: Individual newspaper year files with LID system predictions
#     - .json: Newspaper-level statistics file (stats.json) used by ensemble
#
# STAMP API VERSION:
#   --stamp-api v2
#     Uses v2 API where file stamps match S3 object names exactly (NO .stamp suffix).
#     This allows stats.json stamp to coexist naturally with newspaper file stamps
#     (WTCH-*.jsonl.bz2) in the same directory.
#     
#     Key behavior: Individual files get stamps with SAME name as S3 file.
#     This makes build rules simpler and tracking clearer.
#
# STAMP BEHAVIOR:
#   - File stamps match S3 object names exactly (no suffix)
#   - Example: S3 file "stats.json" → local stamp "stats.json" (0-byte file)
#   - Example: S3 file "WTCH-1828.jsonl.bz2" → local stamp "WTCH-1828.jsonl.bz2" (0-byte file)
#   - Stamps have timestamps matching S3 object modification times
#   - Dangling stamps are removed if corresponding S3 objects no longer exist
#
# SCRIPT: impresso_cookbook.s3_to_local_stamps
#   --local-dir: Base directory for stamp hierarchy
#   --stamp-mode per-file: Create one stamp per S3 file with exact filename
#   --file-extensions: Only sync these file types (filters S3 listing)
#   --remove-dangling-stamps: Clean up orphaned stamps
# Persistent marker updated after successful synchronization. Used by
# downstream targets for dependency/timestamp tracking. Requesting this marker
# directly only ensures it exists; use sync-langident or sync-langident-stage1
# to force a fresh S3 query.
$(LOCAL_PATH_LANGIDENT_STAGE1).last_synced:
	$(MAKE) sync-langident-stage1

# Phony operation: always queries S3 when explicitly requested.
sync-langident-stage1:
	# Syncing the processed data from $(S3_PATH_LANGIDENT_STAGE1)
	#
	# to $(LOCAL_PATH_LANGIDENT_STAGE1)
	mkdir -p $(dir $(LOCAL_LANGIDENT_STAGE1_SYNC_STAMP_FILE)) \
	&& \
	$(PYTHON) -m impresso_cookbook.s3_to_local_stamps \
		$(S3_PATH_LANGIDENT_STAGE1) \
		--local-dir $(BUILD_DIR) \
		--stamp-mode per-file \
		--file-extensions jsonl.bz2 json \
		--remove-dangling-stamps \
		--logfile $(LOCAL_LANGIDENT_STAGE1_SYNC_STAMP_FILE).log.gz \
		--log-level $(LOGGING_LEVEL) \
	&& touch $(LOCAL_LANGIDENT_STAGE1_SYNC_STAMP_FILE)




# TARGET: sync-langident
# Master synchronization target for all language identification data stages.
#
# PURPOSE:
#   Synchronizes both component data (Stage 1a/1b) and ensemble output (final stage)
#   from S3 to local stamp files. This is typically used when resuming work or
#   when multiple machines need to coordinate on distributed processing.
#
# OPERATION TARGETS:
#   1. sync-langident-stage1
#      - Always syncs Stage 1a/1b component data when requested.
#   
#   2. sync-langident-final
#      - Always syncs Ensemble stage output when requested.
#
# PERSISTENT MARKERS:
#   - $(LOCAL_LANGIDENT_STAGE1_SYNC_STAMP_FILE)
#   - $(LOCAL_LANGIDENT_SYNC_STAMP_FILE)
#   These are updated after successful synchronization and remain available for
#   downstream dependency/timestamp tracking. They do not control whether an
#   explicit sync-langident request queries S3.
#
# PROCESSING DEPENDENCIES:
#   Stage 1a → Stage 1b → Ensemble
#   
#   - Stage 1a produces per-year predictions from each LID system
#   - Stage 1b aggregates Stage 1a to compute newspaper-wide statistics
#   - Ensemble uses both Stage 1a (predictions) and Stage 1b (statistics) to decide final language
#
# USAGE EXAMPLES:
#   # Sync all langident data for current newspaper
#   make sync-langident NEWSPAPER=BL/WTCH
#   
#   # Sync before resuming ensemble processing
#   make sync-langident NEWSPAPER=actionfem
#   make langident-ensemble-target NEWSPAPER=actionfem
#   
#   # Sync before distributed processing
#   make sync-langident NEWSPAPER=BL/WTCH
#   make langident-target NEWSPAPER=BL/WTCH
#
# WHAT THIS DOES NOT SYNC:
#   - Input canonical data (use sync-canonical for that)
#   - Other processing stages (lingproc, ocrqa, etc.)
#
sync-langident: sync-langident-stage1 sync-langident-final
.PHONY: sync-langident sync-langident-stage1 sync-langident-final

help-sync::
	@echo ""
	@echo "LANGIDENT SYNC:"
	@echo "  sync-langident # Synchronize langident stage1 and ensemble data from/to S3"

# TARGET: clean-sync-langident
clean-sync-input:: clean-sync-langident

clean-sync-langident:
	rm -fv \
	  $(LOCAL_LANGIDENT_SYNC_STAMP_FILE) \
	  $(LOCAL_LANGIDENT_SYNC_STAMP_FILE).log.gz \
	  $(LOCAL_LANGIDENT_STAGE1_SYNC_STAMP_FILE) \
	  $(LOCAL_LANGIDENT_STAGE1_SYNC_STAMP_FILE).log.gz \
	  || true

.PHONY: clean-sync-langident

help-clean::
	@echo "  clean-sync-langident # Remove local langident sync stamp files"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sync_langident.mk)
