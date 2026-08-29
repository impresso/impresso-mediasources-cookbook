
###############################################################################
# Build System Configuration
# Global settings for shell execution, error handling, and cleanup
#
# This section sets up the shell, enforces strict error handling,
# manages intermediate files, and suppresses default Make rules.
###############################################################################




# SYSTEM CONFIGURATION
# Configure shell and error handling


# USER-VARIABLE: SHELL
# Defines the shell to use for executing commands.
#
# This setting ensures that all commands run within the specified shell.
SHELL ?= /bin/dash
  $(call log.info, SHELL)

# VARIABLE: SHELLOPTS
# Enables strict error handling for the shell.
#
# - errexit: Exit immediately if a command exits with a non-zero status.
# - pipefail: Return the exit status of the last command in a pipeline that failed.
export SHELLOPTS := errexit:pipefail


# SPECIAL VARIABLE: MAKEFLAGS
# SETTINGS FOR THE MAKE PROGRAM
# Enable warning for undefined variables
export MAKEFLAGS += --warn-undefined-variables --no-builtin-rules --no-builtin-variables 
  $(call log.debug, MAKEFLAGS)

# SPECIAL TARGET: .SECONDARY
# Preserve intermediate files generated during the build process.
#
# Without this, intermediate files may be automatically deleted.
.SECONDARY:


# SPECIAL TARGET: .DELETE_ON_ERROR
# Delete intermediate files if the target fails.
#
# Ensures that partially generated files do not remain in case of an error.
.DELETE_ON_ERROR:


# SPECIAL TARGET: .SUFFIXES
# Suppress all default suffix-based implicit rules.
#
# This prevents Make from using built-in suffix-based rules, ensuring only explicitly defined rules apply.
.SUFFIXES:


# VARIABLE: EMPTY
# Defines an empty string variable.
#
# This is useful for various Makefile constructs where an empty value is needed.
EMPTY :=
  $(call log.debug, EMPTY)


# Keep make output concise for longish recipes
ifneq ($(findstring DEBUG,$(LOGGING_LEVEL)),)
  MAKE_SILENCE_RECIPE ?= 
else
  MAKE_SILENCE_RECIPE ?= @
endif
  $(call log.info, MAKE_SILENCE_RECIPE)
