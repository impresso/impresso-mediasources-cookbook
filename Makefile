# Makefile for mediasources processing
# Read the README.md for more information, or run `make` for help.

include cookbook/log.mk

CONFIG_LOCAL_MAKE ?= config.local.mk
-include $(CONFIG_LOCAL_MAKE)

  $(call log.info, LOGGING_LEVEL)

#: Show help message
help::
	@echo "Makefile for mediasources processing"
	@echo "Usage: make <target>"
	@echo "Targets:"

.DEFAULT_GOAL := help
.PHONY: help

include cookbook/make_settings.mk

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

include cookbook/local_to_s3.mk

