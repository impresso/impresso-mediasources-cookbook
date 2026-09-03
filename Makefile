# Makefile for mediasources processing
# Read the README.md for more information, or run `make` for help.

include cookbook/log.mk

-include .env

CFG ?= $(or $(strip $(CONFIG_LOCAL_MAKE)),config.local.mk)
CONFIG_LOCAL_MAKE := $(CFG)
-include $(CFG)

  $(call log.info, LOGGING_LEVEL)

include cookbook/help.mk

.DEFAULT_GOAL := help

include cookbook/make_settings.mk

NPROC_RAW := $(value NPROC)
override NPROC := $(or $(strip $(NPROC_RAW)),1)
COLLECTION_JOBS_RAW := $(value COLLECTION_JOBS)
override COLLECTION_JOBS := $(or $(strip $(COLLECTION_JOBS_RAW)),1)

include cookbook/setup.mk
include cookbook/setup_python.mk
include cookbook/setup_mediasources.mk

include cookbook/newspaper_list.mk

include cookbook/paths_rebuilt.mk
include cookbook/paths_mediasources.mk

include cookbook/main_targets.mk

include cookbook/sync.mk
include cookbook/sync_rebuilt.mk
include cookbook/sync_mediasources.mk

include cookbook/clean.mk

include cookbook/processing.mk
include cookbook/processing_mediasources.mk

include cookbook/aggregators_mediasources.mk

include cookbook/local_to_s3.mk
