$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/paths_reocr.mk)
###############################################################################
# reocr Configuration
###############################################################################

S3_BUCKET_reocr ?= 140-processed-data-sandbox
  $(call log.debug, S3_BUCKET_reocr)

S3_BUCKET_REOCR_INPUT ?= 112-canonical-final
  $(call log.debug, S3_BUCKET_REOCR_INPUT)

PROCESS_LABEL_reocr ?= reocr
  $(call log.debug, PROCESS_LABEL_reocr)

PROCESS_SUBTYPE_LABEL_reocr ?=
  $(call log.debug, PROCESS_SUBTYPE_LABEL_reocr)

TASK_reocr ?= page-tesseract
  $(call log.debug, TASK_reocr)

MODEL_ID_reocr ?= german_print_20
  $(call log.debug, MODEL_ID_reocr)

HF_TESSERACT_REPO_reocr ?= impresso-project/german_print_20
  $(call log.debug, HF_TESSERACT_REPO_reocr)

HF_TESSERACT_MODEL_reocr ?= german_print_20.traineddata
  $(call log.debug, HF_TESSERACT_MODEL_reocr)

TESSERACT_MODEL_URL_reocr ?= https://raw.githubusercontent.com/JKamlah/german-print-ocr-model/main/data/tesseract/best/german_print/german_print_20.traineddata
  $(call log.debug, TESSERACT_MODEL_URL_reocr)

HF_FONT_REPO_reocr ?=
  $(call log.debug, HF_FONT_REPO_reocr)

HF_FONT_MODEL_reocr ?=
  $(call log.debug, HF_FONT_MODEL_reocr)

REOCR_YEARS ?=
  $(call log.debug, REOCR_YEARS)

REOCR_SLEEP_AFTER ?= 1.0
  $(call log.debug, REOCR_SLEEP_AFTER)

REOCR_FALLBACK_CONFIDENCE ?= 0
  $(call log.debug, REOCR_FALLBACK_CONFIDENCE)

REOCR_FALLBACK_DIFF_RATIO ?= 0.5
  $(call log.debug, REOCR_FALLBACK_DIFF_RATIO)

REOCR_SKEW_THRESHOLD ?= 1.5
  $(call log.debug, REOCR_SKEW_THRESHOLD)

REOCR_LINE_MARGIN_EXTEND ?= 0
  $(call log.debug, REOCR_LINE_MARGIN_EXTEND)

REOCR_VERTICAL_MARGIN_REDUCE ?= 0
  $(call log.debug, REOCR_VERTICAL_MARGIN_REDUCE)

REOCR_NO_SKEW ?= 0
  $(call log.debug, REOCR_NO_SKEW)

REOCR_NO_PSM ?= 0
  $(call log.debug, REOCR_NO_PSM)

REOCR_MASK_TOKENS ?= 0
  $(call log.debug, REOCR_MASK_TOKENS)

REOCR_DEBUG ?= 0
  $(call log.debug, REOCR_DEBUG)

PROCESS_COLLECTED_LABEL_reocr ?= reocr-collected
  $(call log.debug, PROCESS_COLLECTED_LABEL_reocr)

REOCR_COLLECT_YEARS ?= $(REOCR_YEARS)
  $(call log.debug, REOCR_COLLECT_YEARS)

REOCR_NORMALIZATION_PROFILE ?= hyphen-ascii
  $(call log.debug, REOCR_NORMALIZATION_PROFILE)

REOCR_NORMALIZATION_CONFIG ?=
  $(call log.debug, REOCR_NORMALIZATION_CONFIG)

REOCR_SYNTHESIZE_FALLBACK_LINES ?= 1
  $(call log.debug, REOCR_SYNTHESIZE_FALLBACK_LINES)

RUN_VERSION_reocr ?= v1-0-0
  $(call log.debug, RUN_VERSION_reocr)

RUN_ID_reocr := $(PROCESS_LABEL_reocr)-$(TASK_reocr)-$(MODEL_ID_reocr)_$(RUN_VERSION_reocr)
  $(call log.debug, RUN_ID_reocr)

PATH_REOCR_INPUT := $(S3_BUCKET_REOCR_INPUT)/$(CANONICAL_PATH_SEGMENT)/pages
  $(call log.debug, PATH_REOCR_INPUT)

S3_PATH_REOCR_INPUT := s3://$(PATH_REOCR_INPUT)
  $(call log.debug, S3_PATH_REOCR_INPUT)

LOCAL_PATH_REOCR_INPUT := $(BUILD_DIR)/$(PATH_REOCR_INPUT)
  $(call log.debug, LOCAL_PATH_REOCR_INPUT)

REOCR_INPUT_TITLE := $(notdir $(CANONICAL_PATH_SEGMENT))
  $(call log.debug, REOCR_INPUT_TITLE)

REOCR_INPUT_YEAR_DIRS := $(foreach year,$(REOCR_YEARS),$(REOCR_INPUT_TITLE)-$(year))
  $(call log.debug, REOCR_INPUT_YEAR_DIRS)

REOCR_COLLECT_YEAR_DIRS := $(foreach year,$(REOCR_COLLECT_YEARS),$(REOCR_INPUT_TITLE)-$(year))
  $(call log.debug, REOCR_COLLECT_YEAR_DIRS)

REOCR_INPUT_SINGLE_YEAR_DIR := $(if $(filter 1,$(words $(REOCR_INPUT_YEAR_DIRS))),$(firstword $(REOCR_INPUT_YEAR_DIRS)))
  $(call log.debug, REOCR_INPUT_SINGLE_YEAR_DIR)

S3_PATH_REOCR_INPUT_SYNC := $(S3_PATH_REOCR_INPUT)$(if $(REOCR_INPUT_SINGLE_YEAR_DIR),/$(REOCR_INPUT_SINGLE_YEAR_DIR))
  $(call log.debug, S3_PATH_REOCR_INPUT_SYNC)

LOCAL_REOCR_INPUT_SYNC_STAMP_FILES := $(if $(REOCR_INPUT_YEAR_DIRS),$(foreach dir,$(REOCR_INPUT_YEAR_DIRS),$(LOCAL_PATH_REOCR_INPUT)/$(dir).last_synced),$(LOCAL_PATH_REOCR_INPUT).last_synced)
  $(call log.debug, LOCAL_REOCR_INPUT_SYNC_STAMP_FILES)

LOCAL_REOCR_INPUT_SYNC_STAMP_FILE := $(firstword $(LOCAL_REOCR_INPUT_SYNC_STAMP_FILES))
  $(call log.debug, LOCAL_REOCR_INPUT_SYNC_STAMP_FILE)

REOCR_INPUT_FILE_GLOBS := $(if $(REOCR_INPUT_YEAR_DIRS),$(foreach dir,$(REOCR_INPUT_YEAR_DIRS),$(LOCAL_PATH_REOCR_INPUT)/$(dir)/*.jsonl.bz2),$(LOCAL_PATH_REOCR_INPUT)/*/*.jsonl.bz2)
  $(call log.debug, REOCR_INPUT_FILE_GLOBS)

PATH_reocr := $(S3_BUCKET_reocr)/$(PROCESS_LABEL_reocr)$(PROCESS_SUBTYPE_LABEL_reocr)/$(RUN_ID_reocr)/$(CANONICAL_PATH_SEGMENT)
  $(call log.debug, PATH_reocr)

S3_PATH_reocr := s3://$(PATH_reocr)
  $(call log.debug, S3_PATH_reocr)

S3_PATH_reocr_PAGES := $(S3_PATH_reocr)/pages
  $(call log.debug, S3_PATH_reocr_PAGES)

S3_PATH_reocr_PAGES_SYNC := $(S3_PATH_reocr_PAGES)$(if $(REOCR_INPUT_SINGLE_YEAR_DIR),/$(REOCR_INPUT_SINGLE_YEAR_DIR))
  $(call log.debug, S3_PATH_reocr_PAGES_SYNC)

S3_PATH_reocr_STAMPS := $(S3_PATH_reocr)/stamps
  $(call log.debug, S3_PATH_reocr_STAMPS)

S3_PATH_reocr_STAMPS_SYNC := $(S3_PATH_reocr_STAMPS)$(if $(REOCR_INPUT_SINGLE_YEAR_DIR),/$(REOCR_INPUT_SINGLE_YEAR_DIR))
  $(call log.debug, S3_PATH_reocr_STAMPS_SYNC)

S3_PATH_reocr_LOGS := $(S3_PATH_reocr)/logs
  $(call log.debug, S3_PATH_reocr_LOGS)

LOCAL_PATH_reocr := $(BUILD_DIR)/$(PATH_reocr)
  $(call log.debug, LOCAL_PATH_reocr)

LOCAL_PATH_reocr_PAGES := $(LOCAL_PATH_reocr)/pages
  $(call log.debug, LOCAL_PATH_reocr_PAGES)

LOCAL_reocr_PAGES_SYNC_STAMP_FILE := $(LOCAL_PATH_reocr_PAGES)$(if $(REOCR_INPUT_SINGLE_YEAR_DIR),/$(REOCR_INPUT_SINGLE_YEAR_DIR)).last_synced
  $(call log.debug, LOCAL_reocr_PAGES_SYNC_STAMP_FILE)

LOCAL_reocr_PAGES_SYNC_STAMP_FILES := $(if $(REOCR_INPUT_YEAR_DIRS),$(foreach dir,$(REOCR_INPUT_YEAR_DIRS),$(LOCAL_PATH_reocr_PAGES)/$(dir).last_synced),$(LOCAL_PATH_reocr_PAGES).last_synced)
  $(call log.debug, LOCAL_reocr_PAGES_SYNC_STAMP_FILES)

LOCAL_PATH_reocr_STAMPS := $(LOCAL_PATH_reocr)/stamps
  $(call log.debug, LOCAL_PATH_reocr_STAMPS)

LOCAL_reocr_SYNC_STAMP_FILE := $(LOCAL_PATH_reocr_STAMPS)$(if $(REOCR_INPUT_SINGLE_YEAR_DIR),/$(REOCR_INPUT_SINGLE_YEAR_DIR)).last_synced
  $(call log.debug, LOCAL_reocr_SYNC_STAMP_FILE)

LOCAL_reocr_SYNC_STAMP_FILES := $(if $(REOCR_INPUT_YEAR_DIRS),$(foreach dir,$(REOCR_INPUT_YEAR_DIRS),$(LOCAL_PATH_reocr_STAMPS)/$(dir).last_synced),$(LOCAL_PATH_reocr_STAMPS).last_synced)
  $(call log.debug, LOCAL_reocr_SYNC_STAMP_FILES)

LOCAL_PATH_reocr_LOGS := $(LOCAL_PATH_reocr)/logs
  $(call log.debug, LOCAL_PATH_reocr_LOGS)

LOCAL_PATH_reocr_WORK := $(LOCAL_PATH_reocr)/work
  $(call log.debug, LOCAL_PATH_reocr_WORK)

PATH_reocr_COLLECTED := $(S3_BUCKET_reocr)/$(PROCESS_COLLECTED_LABEL_reocr)/$(RUN_ID_reocr)/$(CANONICAL_PATH_SEGMENT)
  $(call log.debug, PATH_reocr_COLLECTED)

S3_PATH_reocr_COLLECTED := s3://$(PATH_reocr_COLLECTED)
  $(call log.debug, S3_PATH_reocr_COLLECTED)

S3_PATH_reocr_COLLECTED_PAGES := $(S3_PATH_reocr_COLLECTED)/pages
  $(call log.debug, S3_PATH_reocr_COLLECTED_PAGES)

S3_PATH_reocr_COLLECTED_STATS := $(S3_PATH_reocr_COLLECTED)/stats
  $(call log.debug, S3_PATH_reocr_COLLECTED_STATS)

S3_PATH_reocr_COLLECTED_LOGS := $(S3_PATH_reocr_COLLECTED)/logs
  $(call log.debug, S3_PATH_reocr_COLLECTED_LOGS)

S3_PATH_reocr_COLLECTED_STAMPS := $(S3_PATH_reocr_COLLECTED)/stamps
  $(call log.debug, S3_PATH_reocr_COLLECTED_STAMPS)

LOCAL_PATH_reocr_COLLECTED := $(BUILD_DIR)/$(PATH_reocr_COLLECTED)
  $(call log.debug, LOCAL_PATH_reocr_COLLECTED)

LOCAL_PATH_reocr_COLLECTED_PAGES := $(LOCAL_PATH_reocr_COLLECTED)/pages
  $(call log.debug, LOCAL_PATH_reocr_COLLECTED_PAGES)

LOCAL_PATH_reocr_COLLECTED_STATS := $(LOCAL_PATH_reocr_COLLECTED)/stats
  $(call log.debug, LOCAL_PATH_reocr_COLLECTED_STATS)

LOCAL_PATH_reocr_COLLECTED_LOGS := $(LOCAL_PATH_reocr_COLLECTED)/logs
  $(call log.debug, LOCAL_PATH_reocr_COLLECTED_LOGS)

LOCAL_PATH_reocr_COLLECTED_STAMPS := $(LOCAL_PATH_reocr_COLLECTED)/stamps
  $(call log.debug, LOCAL_PATH_reocr_COLLECTED_STAMPS)

LOCAL_reocr_COLLECTED_SYNC_STAMP_FILE := $(LOCAL_PATH_reocr_COLLECTED).last_synced
  $(call log.debug, LOCAL_reocr_COLLECTED_SYNC_STAMP_FILE)

help-path-variables::
	@echo ""
	@echo "RE-OCR INPUT PATHS:"
	@echo "  S3_BUCKET_REOCR_INPUT=$(S3_BUCKET_REOCR_INPUT)"
	@echo "  S3_PATH_REOCR_INPUT=$(S3_PATH_REOCR_INPUT)"
	@echo "  S3_PATH_REOCR_INPUT_SYNC=$(S3_PATH_REOCR_INPUT_SYNC)"
	@echo "  LOCAL_PATH_REOCR_INPUT=$(LOCAL_PATH_REOCR_INPUT)"
	@echo "  LOCAL_REOCR_INPUT_SYNC_STAMP_FILES=$(LOCAL_REOCR_INPUT_SYNC_STAMP_FILES)"
	@echo "  LOCAL_REOCR_INPUT_SYNC_STAMP_FILE=$(LOCAL_REOCR_INPUT_SYNC_STAMP_FILE)"
	@echo "  REOCR_YEARS=$(REOCR_YEARS)"
	@echo "  REOCR_INPUT_FILE_GLOBS=$(REOCR_INPUT_FILE_GLOBS)"
	@echo ""
	@echo "RE-OCR OUTPUT PATHS:"
	@echo "  S3_BUCKET_reocr=$(S3_BUCKET_reocr)"
	@echo "  PROCESS_LABEL_reocr=$(PROCESS_LABEL_reocr)"
	@echo "  PROCESS_SUBTYPE_LABEL_reocr=$(PROCESS_SUBTYPE_LABEL_reocr)"
	@echo "  TASK_reocr=$(TASK_reocr)"
	@echo "  MODEL_ID_reocr=$(MODEL_ID_reocr)"
	@echo "  RUN_VERSION_reocr=$(RUN_VERSION_reocr)"
	@echo "  RUN_ID_reocr=$(RUN_ID_reocr)"
	@echo "  S3_PATH_reocr=$(S3_PATH_reocr)"
	@echo "  S3_PATH_reocr_PAGES=$(S3_PATH_reocr_PAGES)"
	@echo "  S3_PATH_reocr_PAGES_SYNC=$(S3_PATH_reocr_PAGES_SYNC)"
	@echo "  S3_PATH_reocr_STAMPS=$(S3_PATH_reocr_STAMPS)"
	@echo "  S3_PATH_reocr_STAMPS_SYNC=$(S3_PATH_reocr_STAMPS_SYNC)"
	@echo "  S3_PATH_reocr_LOGS=$(S3_PATH_reocr_LOGS)"
	@echo "  LOCAL_PATH_reocr=$(LOCAL_PATH_reocr)"
	@echo "  LOCAL_PATH_reocr_PAGES=$(LOCAL_PATH_reocr_PAGES)"
	@echo "  LOCAL_reocr_PAGES_SYNC_STAMP_FILES=$(LOCAL_reocr_PAGES_SYNC_STAMP_FILES)"
	@echo "  LOCAL_reocr_PAGES_SYNC_STAMP_FILE=$(LOCAL_reocr_PAGES_SYNC_STAMP_FILE)"
	@echo "  LOCAL_PATH_reocr_STAMPS=$(LOCAL_PATH_reocr_STAMPS)"
	@echo "  LOCAL_reocr_SYNC_STAMP_FILES=$(LOCAL_reocr_SYNC_STAMP_FILES)"
	@echo "  LOCAL_reocr_SYNC_STAMP_FILE=$(LOCAL_reocr_SYNC_STAMP_FILE)"
	@echo "  LOCAL_PATH_reocr_LOGS=$(LOCAL_PATH_reocr_LOGS)"
	@echo "  LOCAL_PATH_reocr_WORK=$(LOCAL_PATH_reocr_WORK)"
	@echo ""
	@echo "RE-OCR COLLECTED OUTPUT PATHS:"
	@echo "  PROCESS_COLLECTED_LABEL_reocr=$(PROCESS_COLLECTED_LABEL_reocr)"
	@echo "  REOCR_COLLECT_YEARS=$(REOCR_COLLECT_YEARS)"
	@echo "  REOCR_NORMALIZATION_PROFILE=$(REOCR_NORMALIZATION_PROFILE)"
	@echo "  REOCR_NORMALIZATION_CONFIG=$(REOCR_NORMALIZATION_CONFIG)"
	@echo "  REOCR_SYNTHESIZE_FALLBACK_LINES=$(REOCR_SYNTHESIZE_FALLBACK_LINES)"
	@echo "  REOCR_COLLECT_YEAR_DIRS=$(REOCR_COLLECT_YEAR_DIRS)"
	@echo "  S3_PATH_reocr_COLLECTED=$(S3_PATH_reocr_COLLECTED)"
	@echo "  S3_PATH_reocr_COLLECTED_PAGES=$(S3_PATH_reocr_COLLECTED_PAGES)"
	@echo "  S3_PATH_reocr_COLLECTED_STATS=$(S3_PATH_reocr_COLLECTED_STATS)"
	@echo "  S3_PATH_reocr_COLLECTED_LOGS=$(S3_PATH_reocr_COLLECTED_LOGS)"
	@echo "  S3_PATH_reocr_COLLECTED_STAMPS=$(S3_PATH_reocr_COLLECTED_STAMPS)"
	@echo "  LOCAL_PATH_reocr_COLLECTED=$(LOCAL_PATH_reocr_COLLECTED)"
	@echo "  LOCAL_PATH_reocr_COLLECTED_PAGES=$(LOCAL_PATH_reocr_COLLECTED_PAGES)"
	@echo "  LOCAL_PATH_reocr_COLLECTED_STATS=$(LOCAL_PATH_reocr_COLLECTED_STATS)"
	@echo "  LOCAL_PATH_reocr_COLLECTED_LOGS=$(LOCAL_PATH_reocr_COLLECTED_LOGS)"
	@echo "  LOCAL_PATH_reocr_COLLECTED_STAMPS=$(LOCAL_PATH_reocr_COLLECTED_STAMPS)"
	@echo "  LOCAL_reocr_COLLECTED_SYNC_STAMP_FILE=$(LOCAL_reocr_COLLECTED_SYNC_STAMP_FILE)"
	@echo ""
	@echo "RE-OCR MODEL SETTINGS:"
	@echo "  HF_TESSERACT_REPO_reocr=$(HF_TESSERACT_REPO_reocr)"
	@echo "  HF_TESSERACT_MODEL_reocr=$(HF_TESSERACT_MODEL_reocr)"
	@echo "  TESSERACT_MODEL_URL_reocr=$(TESSERACT_MODEL_URL_reocr)"
	@echo "  HF_FONT_REPO_reocr=$(HF_FONT_REPO_reocr)"
	@echo "  HF_FONT_MODEL_reocr=$(HF_FONT_MODEL_reocr)"
	@echo ""
	@echo "RE-OCR PROCESSING SETTINGS:"
	@echo "  REOCR_SLEEP_AFTER=$(REOCR_SLEEP_AFTER)"
	@echo "  REOCR_FALLBACK_CONFIDENCE=$(REOCR_FALLBACK_CONFIDENCE)"
	@echo "  REOCR_FALLBACK_DIFF_RATIO=$(REOCR_FALLBACK_DIFF_RATIO)"
	@echo "  REOCR_SKEW_THRESHOLD=$(REOCR_SKEW_THRESHOLD)"
	@echo "  REOCR_LINE_MARGIN_EXTEND=$(REOCR_LINE_MARGIN_EXTEND)"
	@echo "  REOCR_VERTICAL_MARGIN_REDUCE=$(REOCR_VERTICAL_MARGIN_REDUCE)"
	@echo "  REOCR_NO_SKEW=$(REOCR_NO_SKEW)"
	@echo "  REOCR_NO_PSM=$(REOCR_NO_PSM)"
	@echo "  REOCR_MASK_TOKENS=$(REOCR_MASK_TOKENS)"
	@echo "  REOCR_DEBUG=$(REOCR_DEBUG)"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/paths_reocr.mk)
