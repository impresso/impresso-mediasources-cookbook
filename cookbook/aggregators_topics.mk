$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/aggregators_topics.mk)

###############################################################################
# TOPIC ASSIGNMENT AGGREGATORS
# Builds run-level aggregates from per-newspaper topic assignment files.
###############################################################################


# VARIABLE: S3_PATH_TOPICS_RUN_ROOT
# S3 prefix for run-level topic outputs, without the newspaper-specific suffix.
S3_PATH_TOPICS_RUN_ROOT ?= s3://$(S3_BUCKET_TOPICS)/$(PROCESS_LABEL_TOPICS)/$(RUN_ID_TOPICS)
  $(call log.debug, S3_PATH_TOPICS_RUN_ROOT)


# VARIABLE: S3_PATH_TOPICS_AGGREGATED_PREFIX
# Cookbook convention for run-level aggregate products.
S3_PATH_TOPICS_AGGREGATED_PREFIX ?= $(S3_PATH_TOPICS_RUN_ROOT)__AGGREGATED
  $(call log.debug, S3_PATH_TOPICS_AGGREGATED_PREFIX)


# USER-VARIABLE: TOPICS_AGGREGATION_LANGUAGES
# Languages to include in topic aggregate outputs.
TOPICS_AGGREGATION_LANGUAGES ?= $(TOPICS_LANGUAGES)
  $(call log.debug, TOPICS_AGGREGATION_LANGUAGES)


# TARGET: aggregate-topics
#: Builds topic aggregate products for each configured language
aggregate-topics:
	python3 lib/aggregate_topic_assignments.py \
	  --s3-prefix $(S3_PATH_TOPICS_RUN_ROOT) \
	  --output-prefix $(S3_PATH_TOPICS_AGGREGATED_PREFIX) \
	  --languages $(TOPICS_AGGREGATION_LANGUAGES) \
	  --log-level $(LOGGING_LEVEL)

# TARGET: aggregate
#: Conventional cookbook aggregation entry point for topic outputs
aggregate: aggregate-topics

.PHONY: aggregate aggregate-topics

help-aggregation::
	@echo "TOPIC AGGREGATION:"
	@echo "  aggregate-topics  # Build YTDF and DTCI topic aggregates per language"
	@echo "                    # YTDF: yearly topic distribution fingerprint"
	@echo "                    # DTCI: dominant topic content index"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/aggregators_topics.mk)
