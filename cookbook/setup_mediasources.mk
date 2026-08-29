$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_mediasources.mk)

###############################################################################
# SETUP TARGETS
###############################################################################


setup:: check-mediasources-dummy


check-mediasources-dummy:
	@echo "mediasources setup done"
.PHONY: check-mediasources-dummy

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_mediasources.mk)

