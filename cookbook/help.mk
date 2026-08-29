$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/help.mk)

###############################################################################
# HELP TARGETS
# Shared help index and debug-variable inspection.
###############################################################################

.PHONY: help help-orchestration help-processing help-sync help-setup
.PHONY: help-path-variables help-sampling help-aggregation help-clean help-debug
.PHONY: debug-vars print-debug-vars

define help.print_var
@printf '  %-38s %s\n' '$(strip $(1))' '$($(strip $(1)))'
endef

define help.print_var_if_known
$(if $(filter undefined,$(origin $(strip $(1)))),,$(call help.print_var,$(1)))
endef

# DOUBLE-COLON-TARGET: help
#: Show the short help index
help::
	@echo "Impresso make cookbook help"
	@echo ""
	@echo "Usage:"
	@echo "  make help-<topic>"
	@echo ""
	@echo "Help topics:"
	@echo "  help-orchestration  # Core newspaper, collection, and parallel run targets"
	@echo "  help-processing     # Generic and active processing targets and flags"
	@echo "  help-sync           # S3 synchronization and sync cleanup targets"
	@echo "  help-setup          # Local setup, Python, AWS, and tool-check targets"
	@echo "  help-path-variables # S3/local path variable families and active values"
	@echo "  help-sampling       # Sampling workflow targets"
	@echo "  help-aggregation    # Aggregation and verification targets"
	@echo "  help-clean          # Local cleanup targets"
	@echo "  help-debug          # Make variable and logging diagnostics"

help-debug::
	@echo "Debug and inspection targets:"
	@echo "  debug-vars          # Re-run Make with LOGGING_LEVEL=DEBUG and print curated variables"
	@echo ""
	@echo "Examples:"
	@echo "  make debug-vars"
	@echo "  make LOGGING_LEVEL=DEBUG help-path-variables"

help-path-variables::
	@echo "PATH VARIABLE FAMILIES:"
	@echo "  S3_BUCKET_*       # Remote bucket name"
	@echo "  PROCESS_LABEL_*   # Processing family label used in run paths"
	@echo "  TASK_*            # Task label used in run identifiers"
	@echo "  MODEL_ID_*        # Model/tool identity used in run identifiers"
	@echo "  RUN_VERSION_*     # Version label used in run identifiers"
	@echo "  RUN_ID_*          # Derived process/task/model/version identifier"
	@echo "  S3_PATH_*         # Concrete remote s3:// path"
	@echo "  LOCAL_PATH_*      # Local mirror path under BUILD_DIR"

help-processing::
	@echo "PROCESSING HELP:"
	@echo "  processing-target # Generic entry point extended by processing_*.mk fragments"
	@echo "  Component-specific targets and flags appear below when their fragments are included."

help-sync::
	@echo "SYNC HELP:"
	@echo "  sync              # Generic synchronization entry point when sync.mk is included"
	@echo "  sync-input        # Input synchronization hook extended by included fragments"
	@echo "  sync-output       # Output synchronization hook extended by included fragments"
	@echo "  Component-specific sync targets appear below when their fragments are included."

help-setup::
	@echo "SETUP HELP:"
	@echo "  Setup details are contributed by included setup*.mk fragments."

help-sampling::
	@echo "SAMPLING HELP:"
	@echo "  sample-target     # Generic sampling entry point when sampling.mk is included"
	@echo "  Sampling workflow details appear below when sampling_*.mk fragments are included."

help-aggregation::
	@echo "AGGREGATION HELP:"
	@echo "  aggregate         # Conventional aggregation entry point when an aggregator fragment is included"
	@echo "  Aggregation and verification details appear below when aggregator fragments are included."

help-clean::
	@echo "CLEAN HELP:"
	@echo "  clean             # Generic cleanup entry point when clean.mk is included"
	@echo "  clean-sync        # Generic sync cleanup hook when clean.mk is included"
	@echo "  Component-specific cleanup targets appear below when their fragments are included."

# TARGET: debug-vars
#: Re-run Make with DEBUG logging enabled and print curated variables
debug-vars:
	@$(MAKE) --no-print-directory -f $(firstword $(MAKEFILE_LIST)) LOGGING_LEVEL=DEBUG print-debug-vars

# TARGET: print-debug-vars
#: Print curated Make variables after DEBUG parse-time logging
print-debug-vars:
	@echo ""
	@echo "BUILD CONTEXT:"
	$(call help.print_var,MAKE)
	$(call help.print_var,MAKE_VERSION)
	$(call help.print_var,MAKEFILE_LIST)
	$(call help.print_var,BUILD_DIR)
	$(call help.print_var,OS)
	$(call help.print_var_if_known,PYTHON)
	@echo ""
	@echo "ORCHESTRATION:"
	$(call help.print_var_if_known,NPROC)
	$(call help.print_var_if_known,COLLECTION_JOBS)
	$(call help.print_var_if_known,NEWSPAPER_JOBS)
	$(call help.print_var_if_known,MAX_LOAD)
	$(call help.print_var_if_known,HALT_ON_ERROR)
	@echo ""
	@echo "NEWSPAPER SELECTION:"
	$(call help.print_var_if_known,PROVIDER)
	$(call help.print_var,NEWSPAPER)
	$(call help.print_var_if_known,NEWSPAPERS_TO_PROCESS_FILE)
	$(call help.print_var_if_known,NEWSPAPER_PREFIX)
	$(call help.print_var_if_known,NEWSPAPER_FNMATCH)
	@echo ""
	@echo "REPRESENTATIVE PATHS:"
	$(call help.print_var_if_known,S3_BUCKET_REBUILT)
	$(call help.print_var_if_known,S3_PATH_REBUILT)
	$(call help.print_var_if_known,LOCAL_PATH_REBUILT)
	$(call help.print_var_if_known,RUN_ID_LANGIDENT)
	$(call help.print_var_if_known,S3_PATH_LANGIDENT)
	$(call help.print_var_if_known,LOCAL_PATH_LANGIDENT)
	$(call help.print_var_if_known,RUN_ID_LINGPROC)
	$(call help.print_var_if_known,S3_PATH_LINGPROC)
	$(call help.print_var_if_known,LOCAL_PATH_LINGPROC)
	$(call help.print_var_if_known,RUN_ID_TOPICS)
	$(call help.print_var_if_known,S3_PATH_TOPICS)
	$(call help.print_var_if_known,LOCAL_PATH_TOPICS)
	@echo ""
	@echo "PROCESSING FLAGS:"
	$(call help.print_var_if_known,PROCESSING_S3_OUTPUT_DRY_RUN)
	$(call help.print_var_if_known,PROCESSING_KEEP_TIMESTAMP_ONLY_OPTION)
	$(call help.print_var_if_known,PROCESSING_QUIT_IF_S3_OUTPUT_EXISTS_OPTION)
	$(call help.print_var_if_known,LINGPROC_LOGGING_LEVEL)
	$(call help.print_var_if_known,LINGPROC_VALIDATE_OPTION)
	$(call help.print_var_if_known,LINGPROC_WIP_ENABLED)
	$(call help.print_var_if_known,LINGPROC_WIP_MAX_AGE)
	$(call help.print_var_if_known,LINGPROC_UPLOAD_IF_NEWER_OPTION)
	$(call help.print_var_if_known,LANGIDENT_LOGGING_LEVEL)
	$(call help.print_var_if_known,LANGIDENT_VALIDATE_OPTION)
	$(call help.print_var_if_known,LANGIDENT_WIP_MAX_AGE)
	$(call help.print_var_if_known,TOPICS_LOGGING_LEVEL)
	$(call help.print_var_if_known,TOPICS_MIN_P)
	$(call help.print_var_if_known,TOPICS_WIP_ENABLED)
	$(call help.print_var_if_known,CONSOLIDATEDCANONICAL_WIP_ENABLED)
	$(call help.print_var_if_known,CONSOLIDATEDCANONICAL_WIP_MAX_AGE)
	$(call help.print_var_if_known,CONSOLIDATEDCANONICAL_UPLOAD_IF_NEWER_OPTION)
	$(call help.print_var_if_known,CONSOLIDATEDCANONICAL_FORCE_OVERWRITE_OPTION)

$(call log.debug, COOKBOOK END INCLUDE: cookbook/help.mk)
