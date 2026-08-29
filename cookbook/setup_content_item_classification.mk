$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_content_item_classification.mk)

###############################################################################
# SETUP TARGETS
# Targets for setting up the content_item_classification environment
###############################################################################


setup:: check-content_item_classification-dummy newspaper-list-target


# TARGET: check-template-dummy
check-content_item_classification-dummy:
	@echo "content_item_classification setup done"
.PHONY: check-template-dummy

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_content_item_classification.mk)
