
aggregate:
	python cookbook/lib/s3_aggregator.py --jq-filter cookbook/lib/langident_stats.jq \
	--include-source-meta \
	--s3-prefix $(S3_PATH_LANGIDENT:/$(NEWSPAPER)=) \
	-o $(S3_PATH_LANGIDENT:/$(NEWSPAPER)=)__AGGREGATED.jsonl.gz 

aggregate-for-floret-stats:
#  $(S3_PATH_LANGIDENT:/$(NEWSPAPER)=)__AGGREGATED.for-floret-langident.stats.json: 
	# For .gz compressed
	aws s3 cp $(S3_PATH_LANGIDENT:/$(NEWSPAPER)=)__AGGREGATED.jsonl.gz - | gunzip | \
	jq -s 'map(select((.lg_decision | startswith("dominant") | not) and .len >= 400)) | group_by(.lg) | map({language: .[0].lg, count: length}) | sort_by(.count) | reverse' \
	> $(LOCAL_PATH_LANGIDENT:/$(NEWSPAPER)=)__AGGREGATED.for-floret-langident.stats.json
	aws s3 cp $(LOCAL_PATH_LANGIDENT:/$(NEWSPAPER)=)__AGGREGATED.for-floret-langident.stats.json $(S3_PATH_LANGIDENT:/$(NEWSPAPER)=)__AGGREGATED.for-floret-langident.stats.json




VERIFY_EXTENSIONS ?= jsonl.bz2 json

verify-data::
	@echo "Verifying data readability for $(S3_PATH_LANGIDENT:/$(NEWSPAPER)=)"
	python cookbook/lib/s3_aggregator.py --verify \
	--s3-prefix $(S3_PATH_LANGIDENT:/$(NEWSPAPER)=) \
	$(if $(VERIFY_EXTENSIONS),--verify-file-extensions $(VERIFY_EXTENSIONS),)
verify-data::
	@echo "Verifying data readability for $(S3_PATH_LANGIDENT_STAGE1:/$(NEWSPAPER)=)"
	python cookbook/lib/s3_aggregator.py --verify \
	--s3-prefix $(S3_PATH_LANGIDENT_STAGE1:/$(NEWSPAPER)=) \
	$(if $(VERIFY_EXTENSIONS),--verify-file-extensions $(VERIFY_EXTENSIONS),)

verify-and-clean::
	@echo "Verifying and cleaning corrupted data for $(S3_PATH_LANGIDENT:/$(NEWSPAPER)=)"
	@echo "WARNING: This will DELETE corrupted files!"
	python cookbook/lib/s3_aggregator.py --verify --verify-and-delete \
	--s3-prefix $(S3_PATH_LANGIDENT:/$(NEWSPAPER)=) \
	$(if $(VERIFY_EXTENSIONS),--verify-file-extensions $(VERIFY_EXTENSIONS),)
verify-and-clean::
	@echo "Verifying and cleaning corrupted data for $(S3_PATH_LANGIDENT_STAGE1:/$(NEWSPAPER)=)"
	@echo "WARNING: This will DELETE corrupted files!"
	python cookbook/lib/s3_aggregator.py --verify --verify-and-delete \
	--s3-prefix $(S3_PATH_LANGIDENT_STAGE1:/$(NEWSPAPER)=) \
	$(if $(VERIFY_EXTENSIONS),--verify-file-extensions $(VERIFY_EXTENSIONS),)

help-aggregation::
	@echo "LANGIDENT AGGREGATION:"
	@echo "  aggregate           # Aggregate language identification results for a newspaper"
	@echo "  aggregate-for-floret-stats # Build floret statistics aggregate"
	@echo "  verify-data         # Verify that all language identification data files are readable"
	@echo "                      # Usage: make verify-data [VERIFY_EXTENSIONS='json jsonl.gz']"
	@echo "  verify-and-clean    # Verify data and DELETE corrupted files"
	@echo "                      # Usage: make verify-and-clean [VERIFY_EXTENSIONS='json jsonl.gz']"
