$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_reocr.mk)
###############################################################################
# SETUP TARGETS
###############################################################################

setup:: check-reocr-tools setup-reocr-tesseract-model

check-reocr-tools:
	@command -v tesseract >/dev/null 2>&1 || (echo "Missing required command: tesseract"; exit 1)
	@tesseract --version >/dev/null 2>&1 || (echo "Tesseract is installed but cannot run"; exit 1)
	@command -v ssh >/dev/null 2>&1 || (echo "Missing required command: ssh"; exit 1)

.PHONY: check-reocr-tools

setup-reocr-tesseract-model:
	$(PYTHON) lib/cli_reocr_setup.py \
	  --tesseract-repo $(HF_TESSERACT_REPO_reocr) \
	  --tesseract-model $(HF_TESSERACT_MODEL_reocr) \
	  $(if $(TESSERACT_MODEL_URL_reocr),--tesseract-model-url $(TESSERACT_MODEL_URL_reocr)) \
	  $(if $(HF_FONT_REPO_reocr),--font-repo $(HF_FONT_REPO_reocr)) \
	  $(if $(HF_FONT_MODEL_reocr),--font-model $(HF_FONT_MODEL_reocr)) \
	  --log-level $(LOGGING_LEVEL)

.PHONY: setup-reocr-tesseract-model

check-reocr-tunnel-env:
	@test -n "$$IMPRESSO_CANTALOUPE_USER" || (echo "Missing IMPRESSO_CANTALOUPE_USER"; exit 1)
	@test -n "$$IMPRESSO_CANTALOUPE_PASS" || (echo "Missing IMPRESSO_CANTALOUPE_PASS"; exit 1)
	@test -n "$$IIIF_SSH_USER" || (echo "Missing IIIF_SSH_USER"; exit 1)
	@test -n "$$IIIF_SSH_HOST" || (echo "Missing IIIF_SSH_HOST"; exit 1)

.PHONY: check-reocr-tunnel-env

reocr-tunnel: check-reocr-tools check-reocr-tunnel-env
	$(PYTHON) lib/cli_iiif_tunnel.py

.PHONY: reocr-tunnel

check-reocr-tunnel: check-reocr-tools check-reocr-tunnel-env
	$(PYTHON) lib/cli_iiif_tunnel.py --check

.PHONY: check-reocr-tunnel

help-setup::
	@echo "  setup-reocr-tesseract-model # Download/cache configured HF Tesseract and font models"
	@echo "  reocr-tunnel       # Open and keep the IIIF SSH tunnel alive for parallel re-OCR"
	@echo "  check-reocr-tunnel # Check whether the local IIIF tunnel port is already open"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_reocr.mk)
