$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_consolidatedcanonical.mk)

###############################################################################
# SETUP TARGETS
# Targets for setting up the consolidatedcanonical environment
###############################################################################


setup:: check-consolidatedcanonical-dummy


# TARGET: check-consolidatedcanonical-dummy
check-consolidatedcanonical-dummy:
	@echo "consolidatedcanonical setup done"
.PHONY: check-consolidatedcanonical-dummy

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_consolidatedcanonical.mk)
