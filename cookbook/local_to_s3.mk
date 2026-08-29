$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/local_to_s3.mk)

###############################################################################
# S3 PATH CONVERSION UTILITIES
# Functions for converting between local and S3 paths
###############################################################################

# Safety check: Ensure BUILD_DIR is defined
ifndef BUILD_DIR
$(warning LocalToS3 function requires BUILD_DIR to be defined. Please set BUILD_DIR in your configuration.)
endif

# FUNCTION: LocalToS3_Internal
# Internal function that converts local file paths to their S3 equivalents
# Args:
#   1: Local file path
#   2: Suffix to remove (always receives a value, even if empty)
# Note: Suffix is removed BEFORE path conversion to ensure correct substitution
# Warning: If BUILD_DIR is empty, the conversion will not work correctly
define LocalToS3_Internal
$(if $(BUILD_DIR),$(subst $(BUILD_DIR),s3:/,$(subst $(2),,$(1))),$(error LocalToS3: BUILD_DIR is not set. Cannot convert path: $(1)))
endef

# FUNCTION: LocalToS3
# Converts local file paths to their S3 equivalents
# Args:
#   1: Local file path
#   2: Optional suffix to remove (defaults to empty string if not provided)
# Usage:
#   $(call LocalToS3,path/to/file.txt)           # No suffix removal
#   $(call LocalToS3,path/to/file.txt,.txt)      # Remove .txt suffix
define LocalToS3
$(call LocalToS3_Internal,$(1),$(value 2))
endef

# TARGET: test-LocalToS3
# Runs test cases for the LocalToS3 function
test-LocalToS3:
	@echo "Running tests for LocalToS3 function..."
	@echo "BUILD_DIR is: $(BUILD_DIR)"
	@echo
	@echo "Test 1: Convert local path to S3 path without stripping any suffix"
	@echo "Input: $(BUILD_DIR)/22-rebuilt-final/marieclaire/file.txt"
	@echo "Expected Output: s3://22-rebuilt-final/marieclaire/file.txt"
	@echo "Actual Output  : $(call LocalToS3,$(BUILD_DIR)/22-rebuilt-final/marieclaire/file.txt)"
	@echo
	@echo "Test 2: Convert local path to S3 path and strip the .txt suffix"
	@echo "Input: $(BUILD_DIR)/22-rebuilt-final/marieclaire/file.txt, .txt"
	@echo "Expected Output: s3://22-rebuilt-final/marieclaire/file"
	@echo "Actual Output  : $(call LocalToS3,$(BUILD_DIR)/22-rebuilt-final/marieclaire/file.txt,.txt)"
	@echo
	@echo "Test 3: Convert local path to S3 path and strip a custom suffix"
	@echo "Input: $(BUILD_DIR)/22-rebuilt-final/marieclaire/file.custom, .custom"
	@echo "Expected Output: s3://22-rebuilt-final/marieclaire/file"
	@echo "Actual Output  : $(call LocalToS3,$(BUILD_DIR)/22-rebuilt-final/marieclaire/file.custom,.custom)"
	@echo
	@echo "Test 4: One-argument call (default to no suffix removal)"
	@echo "Input: $(BUILD_DIR)/22-rebuilt-final/marieclaire/file.jsonl.bz2"
	@echo "Expected Output: s3://22-rebuilt-final/marieclaire/file.jsonl.bz2"
	@echo "Actual Output  : $(call LocalToS3,$(BUILD_DIR)/22-rebuilt-final/marieclaire/file.jsonl.bz2)"
	@echo

help-debug::
	@echo "  test-LocalToS3    # Print LocalToS3 conversion test cases"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/local_to_s3.mk)
