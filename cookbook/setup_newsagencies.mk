$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_newsagencies.mk)

###############################################################################
# SETUP TARGETS
# Targets for setting up the newsagencies environment
###############################################################################


setup:: check-newsagencies-dummy


# TARGET: check-newsagencies-dummy
check-newsagencies-dummy:
	@echo "newsagencies setup done"
.PHONY: check-newsagencies-dummy

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_newsagencies.mk)
