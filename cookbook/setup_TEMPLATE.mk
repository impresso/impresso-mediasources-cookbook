$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_TEMPLATE.mk)

###############################################################################
# SETUP TARGETS
# Targets for setting up the TEMPLATE environment
###############################################################################


setup:: check-TEMPLATE-dummy


# TARGET: check-template-dummy
check-TEMPLATE-dummy:
	@echo "TEMPLATE setup done"
.PHONY: check-template-dummy

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_TEMPLATE.mk)
