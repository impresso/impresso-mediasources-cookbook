$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_nel.mk)
###############################################################################
# NEL Setup Configuration
# Defines setup and configuration for NEL processing
###############################################################################

# USER-VARIABLE: NEL_PYTHON_REQUIREMENTS
# Path to the Python requirements file for NEL processing
#
# Specifies the requirements file containing Python dependencies needed for NEL.
NEL_PYTHON_REQUIREMENTS ?= requirements.txt
  $(call log.debug, NEL_PYTHON_REQUIREMENTS)

# Add NEL requirements to the list of Python requirements to install
PYTHON_REQUIREMENTS_FILES += $(NEL_PYTHON_REQUIREMENTS)

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_nel.mk)
