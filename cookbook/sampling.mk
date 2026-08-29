$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/sampling.mk)
###############################################################################
# SAMPLING TARGETS (GENERIC)
# Generic orchestration hooks for data sampling workflows.
#
# Keep cookbook-side logic minimal and reusable.
# Sampling use-case logic (jq and Python recipe scripts) should live in ./lib.
###############################################################################

# DOUBLE-COLON-TARGET: sample-target
#: Abstract sampling entry point
sample-target:: | $(BUILD_DIR)

.PHONY: sample-target

help-sampling::
	@echo "SAMPLING TARGETS:"
	@echo "  sample-target      # Abstract sampling entry point implemented by sampling_*.mk"
	@echo ""
	@echo "SAMPLING VARIABLES:"
	@echo "  SAMPLE_LOG_LEVEL=$(SAMPLE_LOG_LEVEL)"
	@echo "  SAMPLE_RANDOM_SEED=$(SAMPLE_RANDOM_SEED)"
	@echo "  SAMPLE_RATE=$(SAMPLE_RATE)"


# USER-VARIABLE: SAMPLE_LOG_LEVEL
# Logging level used by sampler/compiler scripts.
SAMPLE_LOG_LEVEL ?= INFO
  $(call log.debug, SAMPLE_LOG_LEVEL)

# USER-VARIABLE: SAMPLE_RANDOM_SEED
# Seed value for reproducible random sampling.
SAMPLE_RANDOM_SEED ?= 42
  $(call log.debug, SAMPLE_RANDOM_SEED)

# USER-VARIABLE: SAMPLE_RATE
# Default random sampling rate used by sampling scripts.
SAMPLE_RATE ?= 0.01
  $(call log.debug, SAMPLE_RATE)

$(call log.debug, COOKBOOK END INCLUDE: cookbook/sampling.mk)
