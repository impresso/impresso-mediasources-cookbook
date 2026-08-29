$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_langident.mk)

###############################################################################
# SETUP TARGETS
# Targets for warming Hugging Face caches used by language identification
###############################################################################


setup:: warm-langident-cache


# USER-VARIABLE: LANGIDENT_WARM_CACHE
# If set to 1, warm the Hugging Face-backed langident caches during setup.
# Default is disabled to keep setup lightweight unless explicitly requested.
LANGIDENT_WARM_CACHE ?= 1
  $(call log.debug, LANGIDENT_WARM_CACHE)


# USER-VARIABLE: LANGIDENT_HF_LANGIDENT_REPO_OPTION
# Hugging Face repository used to warm the langident model cache.
LANGIDENT_HF_LANGIDENT_REPO_OPTION ?= impresso-project/impresso-floret-langident
  $(call log.debug, LANGIDENT_HF_LANGIDENT_REPO_OPTION)


# USER-VARIABLE: LANGIDENT_HF_LANGIDENT_REVISION_OPTION
# Hugging Face revision used to warm the langident model cache.
LANGIDENT_HF_LANGIDENT_REVISION_OPTION ?= main
  $(call log.debug, LANGIDENT_HF_LANGIDENT_REVISION_OPTION)


# TARGET: warm-langident-cache
# Serially initialize Hugging Face-backed langident assets so later workers can
# reuse the local cache instead of downloading in parallel.
warm-langident-cache:
ifeq ($(LANGIDENT_WARM_CACHE),1)
	pipenv run python cookbook/setup_langident.py \
		--langident-repo $(LANGIDENT_HF_LANGIDENT_REPO_OPTION) \
		--langident-revision $(LANGIDENT_HF_LANGIDENT_REVISION_OPTION) \
		$(if $(LANGIDENT_OCRQA_OPTION),--ocrqa,) \
		--ocrqa-repo $(if $(LANGIDENT_OCRQA_REPO_OPTION),$(LANGIDENT_OCRQA_REPO_OPTION),impresso-project/OCR-quality-assessment-unigram) \
		--ocrqa-revision $(if $(LANGIDENT_OCRQA_VERSION_OPTION),$(LANGIDENT_OCRQA_VERSION_OPTION),main)
else
	@echo "Skipping langident Hugging Face cache warmup (set LANGIDENT_WARM_CACHE=1 to enable)."
endif

.PHONY: warm-langident-cache


help-setup::
	@echo "  warm-langident-cache # Warm Hugging Face model cache for langident/OCRQA"
	@echo "                       # Controlled by LANGIDENT_WARM_CACHE=$(LANGIDENT_WARM_CACHE)"


$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_langident.mk)
