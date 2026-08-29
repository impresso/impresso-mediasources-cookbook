###############################################################################
# Newspaper Processing Pipeline
# Load necessary Makefile fragments for newspaper processing
#
# This Makefile includes various fragments necessary for setting up,
# processing, and synchronizing newspaper data. It ensures that all required
# dependencies and functions are properly loaded.
###############################################################################

# INCLUDE-FILES: log.mk
# Logging functions
include log.mk

# INCLUDE-FILES: help.mk
# Main help index and debug inspection targets
include help.mk

# INCLUDE-FILES: setup.mk
# General setup targets
include setup.mk

# INCLUDE-FILES: setup_lingproc.mk
# Setup targets for linguistic processing environment
include setup_lingproc.mk

# INCLUDE-FILES: newspaper_list.mk
# Newspaper list management utilities
include newspaper_list.mk

# INCLUDE-FILES: local_to_s3.mk
# S3 path conversion utilities
include local_to_s3.mk

# INCLUDE-FILES: main_targets.mk
# Main processing targets
include main_targets.mk

# INCLUDE-FILES: paths_rebuilt.mk
# Path definitions for rebuilt content
include paths_rebuilt.mk

# INCLUDE-FILES: sync_rebuilt.mk
# Targets for synchronizing rebuilt data from S3 to local storage
include sync_rebuilt.mk

# INCLUDE-FILES: paths_langident.mk
# Path definitions for language identification
include paths_langident.mk

# INCLUDE-FILES: paths_lingproc.mk
# Path definitions for linguistic processing
include paths_lingproc.mk

# INCLUDE-FILES: paths_ocrqa.mk
# Path definitions for OCR Quality Assessment
include paths_ocrqa.mk

# INCLUDE-FILES: sync_lingproc.mk
# Targets for synchronizing processed linguistic data between S3 and local storage
include sync_lingproc.mk

# INCLUDE-FILES: processing_lingproc.mk
# Targets for processing newspaper content with linguistic analysis
include processing_lingproc.mk

# INCLUDE-FILES: clean.mk
# Cleanup targets
include clean.mk

# INCLUDE-FILES: setup_aws.mk
# AWS configuration targets
include setup_aws.mk
