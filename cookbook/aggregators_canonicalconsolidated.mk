

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
	@echo "CONSOLIDATED CANONICAL VERIFICATION:"
	@echo "  aggregate           # Aggregate configured results for a newspaper"
	@echo "  verify-data         # Verify that all data files are readable"
	@echo "                      # Usage: make verify-data [VERIFY_EXTENSIONS='json jsonl.gz']"
	@echo "  verify-and-clean    # Verify data and DELETE corrupted files"
	@echo "                      # Usage: make verify-and-clean [VERIFY_EXTENSIONS='json jsonl.gz']"
