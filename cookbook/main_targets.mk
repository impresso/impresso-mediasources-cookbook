$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/main_targets.mk)
###############################################################################
# MAIN PROCESSING TARGETS
# Core targets for newspaper processing pipeline
###############################################################################
  
  $(call log.info,MAKEFLAGS)

# Cross-platform CPU detection
ifndef NPROC
ifeq ($(OS),Darwin)
# macOS - use sysctl
NPROC := $(shell sysctl -n hw.ncpu 2>/dev/null || echo 1)
else ifeq ($(OS),Linux)
# Linux - use nproc
NPROC := $(shell nproc --all 2>/dev/null || echo 1)
else
# Fallback for other systems
NPROC := 1
  $(call log.warn, "NPROC not set, defaulting to 1. Please set NPROC for better performance.")
endif
endif
  $(call log.info, NPROC)

# USER-VARIABLE: MAX_LOAD
# Maximum load average for the machine to allow processing
#
# This variable sets the maximum load average for the machine in parallelization. No new
# jobs are started if the load average exceeds this value.
MAX_LOAD ?= $(NPROC)
  $(call log.info, MAX_LOAD)

# USER-VARIABLE: COLLECTION_JOBS
# Maximum number of parallel newspaper processes
#
# This variable sets the maximum number of different newspapers to process in parallel.
# Default: Half of available CPU cores
COLLECTION_JOBS_DEFAULT := $(shell v=$$(expr $(NPROC) / 2); [ "$$v" -lt 1 ] && v=1; echo $$v)
COLLECTION_JOBS_RAW := $(value COLLECTION_JOBS)
override COLLECTION_JOBS := $(or $(strip $(COLLECTION_JOBS_RAW)),$(COLLECTION_JOBS_DEFAULT))
  $(call log.info, COLLECTION_JOBS)

# USER-VARIABLE: NEWSPAPER_JOBS
# Maximum number of parallel jobs per newspaper
#
# This variable sets the maximum number of parallel jobs to run when processing a
# single newspaper. Auto-calculated to balance with COLLECTION_JOBS.
# If COLLECTION_JOBS exceeds NPROC, this is clamped to 1 to avoid -j 0 (unlimited jobs).
NEWSPAPER_JOBS_DEFAULT := $(shell if [ "$(COLLECTION_JOBS)" -gt 0 ]; then v=$$(expr $(NPROC) / $(COLLECTION_JOBS)); [ "$$v" -lt 1 ] && v=1; echo $$v; else echo 1; fi)
NEWSPAPER_JOBS_RAW := $(value NEWSPAPER_JOBS)
override NEWSPAPER_JOBS := $(or $(strip $(NEWSPAPER_JOBS_RAW)),$(NEWSPAPER_JOBS_DEFAULT))
  $(call log.info, NEWSPAPER_JOBS)

# PARALLEL_DELAY: Delay in seconds between starting parallel jobs
PARALLEL_DELAY ?= 3
  $(call log.debug, PARALLEL_DELAY)

#: Show detailed orchestration and parallelization help
help-orchestration::
	@echo "PARALLELIZATION CONFIGURATION:"
	@echo "  COLLECTION_JOBS   #  Number of different newspapers to process in parallel ($(COLLECTION_JOBS))"
	@echo "                    #  Low numbers might not use all system resources effectively if newspapers are small and many CPU cores are available"
	@echo ""
	@echo "  NEWSPAPER_JOBS    #  Number of parallel jobs per newspaper ($(NEWSPAPER_JOBS))"
	@echo "                    #  Auto-calculated and clamped to at least 1"
	@echo "                    #  Controls fine-grained parallelism within each newspaper"
	@echo "                    #  Auto-calculated to balance with COLLECTION_JOBS"
	@echo ""
	@echo "  MAX_LOAD          #  Maximum system load average ($(MAX_LOAD))"
	@echo "                    #  Prevents system overload by limiting concurrent processes"
	@echo "                    #  Set lower if system becomes unresponsive"
	@echo ""
	@echo "  NPROC             #  Number of CPU cores ($(NPROC))"
	@echo "                    #  Override if auto-detection fails or for resource limiting"
	@echo ""
	@echo "  HALT_ON_ERROR     #  Stop collection run on first failing job (0 or 1; current: $(HALT_ON_ERROR))"
	@echo ""
	@echo "PERFORMANCE TUNING:"
	@echo "  • For CPU-bound tasks: COLLECTION_JOBS ≤ NPROC"
	@echo "  • For I/O-bound tasks: COLLECTION_JOBS can exceed NPROC"
	@echo "  • High memory usage: Reduce COLLECTION_JOBS"
	@echo "  • System lag: Reduce MAX_LOAD to 70-80% of NPROC"
	@echo ""
	@echo "EXAMPLES:"
	@echo "  make newspaper PROVIDER=BL NEWSPAPER=WTCH"
	@echo "  make collection COLLECTION_JOBS=4 CFG=config.local.mk"
	@echo "  make all PROVIDER=BL NEWSPAPER=WTCH MAX_LOAD=8"
	@echo "  make sync-input PROVIDER=SWA NEWSPAPER=actionfem"
	@echo ""
	@echo "MONITORING:"
	@echo "  tail -f build.d/collection.joblog          # Monitor collection progress"
	@echo "  htop -u $${USER}                           # Monitor system resources"
	@echo ""

.PHONY: help-orchestration
# If set to 1, GNU parallel stops on the first error
HALT_ON_ERROR ?= 0

# Internal option passed to GNU parallel
ifeq ($(HALT_ON_ERROR),1)
PARALLEL_HALT := --halt now,fail=1
else
PARALLEL_HALT :=
endif


# TARGET: newspaper
#: Process a single newspaper run by the processing pipeline
# Dependencies: 
# - sync: Ensures data is synchronized
# - processing-target: Performs the actual processing
newspaper: | $(BUILD_DIR)
	# MAKEFLAGS= $(MAKEFLAGS) 
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) sync
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) processing-target

.PHONY: newspaper

help-orchestration::
	@echo ""
	@echo "CORE RUN TARGETS:"
	@echo "  newspaper         # Sync normally, then process one newspaper"
	@echo "  all               # Force resync input/output, then run processing-target"
	@echo "                    # Prefer newspaper/collection for long runs with per-target S3 WIP checks"


# TARGET: all
# Complete processing with fresh data sync
# Steps:
# 1. Resync data (serial)
# 2. Process data (parallel)
# Note: The two Make invocations are separate to ensure sync completes before processing starts
# Use this target when a forced local sync-state refresh is desired, for example
# before explicit single-newspaper multimachine coordination checks.
all:
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) -j 1 resync-input resync-output
	$(MAKE) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) -j $(NEWSPAPER_JOBS) --max-load $(MAX_LOAD) processing-target

.PHONY: all


# TARGET: collection
#: Process multiple newspapers with specified parallel processing
# Uses xargs for parallel execution with COLLECTION_JOBS limit.
# Each item runs newspaper, not all, so collection refreshes S3-derived stamps
# through normal sync and relies on per-target online S3/WIP checks before
# expensive processing.
collection-xargs: newspaper-list-target | $(BUILD_DIR)
	tr " " "\n" < $(NEWSPAPERS_TO_PROCESS_FILE) | \
	xargs -n 1 -P $(COLLECTION_JOBS) -I {} \
		sh -c 'NEWSPAPER="$$1" $(MAKE) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) -k --max-load $(MAX_LOAD) newspaper' sh {}


check-parallel:
	@parallel --version | grep -q 'GNU parallel' || \
	( echo "ERROR: GNU parallel not installed or a wrong variant"; exit 1 )
.PHONY: check-parallel

# TARGET: collection
#: Process full impresso collection with specified parallel processing
# Uses GNU parallel for better control over job execution
# Note: Requires GNU parallel installed
# Dependencies: newspaper-list-target
# Each item runs newspaper, not all, so collection refreshes S3-derived stamps
# through normal sync and relies on per-target online S3/WIP checks before
# expensive processing.
collection: check-parallel newspaper-list-target | $(BUILD_DIR)
	# tail -f $(BUILD_DIR)/collection.joblog to monitor per newspaper progress summary
	tr -s '[:space:]' '\n'  < $(NEWSPAPERS_TO_PROCESS_FILE) | \
	parallel  --tag -v \
	   --progress \
	   --joblog $(BUILD_DIR)/collection.joblog \
	   --jobs $(COLLECTION_JOBS) \
	   --delay $(PARALLEL_DELAY) \
	   --memfree 1G \
	   --load $(MAX_LOAD) \
	   $(PARALLEL_HALT) \
	   "NEWSPAPER={} $(MAKE) -f $(firstword $(MAKEFILE_LIST)) COLLECTION_JOBS=$(COLLECTION_JOBS) NEWSPAPER_JOBS=$(NEWSPAPER_JOBS) -k -j --max-load $(MAX_LOAD) newspaper"

help-orchestration::
	@echo "  collection-xargs  # Process collection via xargs (fallback when GNU parallel is unavailable)"
	@echo "  collection        # Process full impresso collection with parallel processing"
	@echo "                    # Runs newspaper for each item; recipes do online S3/WIP checks before expensive work"
	@echo "                    # Requires GNU parallel and a valid NEWSPAPERS_TO_PROCESS_FILE"


.PHONY: collection

$(call log.debug, COOKBOOK END INCLUDE: cookbook/main_targets.mk)
