$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup.mk)

###############################################################################
# GENERAL SETUP TARGETS
# Basic setup functionality and directory management
###############################################################################


# USER-VARIABLE: BUILD_DIR
# The build directory where all local input and output files are stored
# The content of BUILD_DIR can be removed anytime without issues regarding s3
BUILD_DIR ?= build.d

# USER-VARIABLE: CFG
# Optional Make configuration file used by downstream project recipes.
# When provided for setup, it must point to an existing regular file.
CFG_VALUE := $(strip $(value CFG))


# USER-VARIABLE: OS
# Detect the operating system if not set from outside
OS ?= $(shell uname -s)
  $(call log.debug, OS)


# VARIABLE: INSTALLER
# Defines the package manager for the software installation on operating system level

# If Linux, check the distribution
ifeq ($(OS),Linux)
  DISTRO := $(shell grep -Ei 'debian|ubuntu' /etc/os-release 2>/dev/null)
  ifneq ($(DISTRO),)
    INSTALLER := apt
  endif

# If macOS, use Homebrew
else ifeq ($(OS),Darwin)
  INSTALLER := brew
endif

# If not set, let make complain about an undefined variable here
  $(call log.debug, INSTALLER)


# PATTERN-RULE: %.d
#: Creates a directory if it doesn't exist
%.d:
	mkdir -p $@


# DOUBLE-COLON-TARGET: setup
#: Sets up the build directory and runs the active setup-<TARGET> targets
setup:: check-cfg-file | $(BUILD_DIR)

.PHONY: setup

# TARGET: check-cfg-file
#: Validate that CFG points to an existing file when CFG is provided
check-cfg-file:
	@if [ -n "$(CFG_VALUE)" ] && [ ! -f "$(CFG_VALUE)" ]; then \
		echo "ERROR: CFG is set to '$(CFG_VALUE)', but that file does not exist." >&2; \
		exit 1; \
	fi

.PHONY: check-cfg-file

help-setup::
	@echo "SETUP TARGETS:"
	@echo "  setup           # Create local directories and run active setup targets"
	@echo "  check-cfg-file  # Validate that CFG points to an existing file when provided"

# USER-VARIABLE: GIT_VERSION
# The current git version of the repository
#
# This variable is used to store the current git version of the repository in output files.
# It is used to track the version of the code that was used to generate the output.
# If not set, it will be determined by the git describe command.
ifndef GIT_VERSION
GIT_VERSION := $(shell git describe --tags --always)
endif
  $(call log.info, GIT_VERSION)
export GIT_VERSION


$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup.mk)
