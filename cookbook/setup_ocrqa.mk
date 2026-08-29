$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_ocrqa.mk)

###############################################################################
# SETUP TARGETS
# Targets for setting up the OCR QA environment
###############################################################################


setup:: check-python-installation-hf


# TARGET: check-python-installation-hf
# Tests Python installation for huggingface hub download
check-python-installation-hf:
	# TEST PYTHON INSTALLATION FOR huggingface hub download ...
	python3 lib/test_hf_installation.py -b $(OCRQA_BLOOMFILTERS_OPTION) || \
	{ echo "Double check whether the required python packages are installed! or you running in the correct python environment!" ; exit 1; }
	# OK: PYTHON ENVIRONMENT IS FINE!

.PHONY: check-python-installation-hf

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_ocrqa.mk)
