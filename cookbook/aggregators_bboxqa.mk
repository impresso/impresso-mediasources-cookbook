
aggregate-pagestats:
	python cookbook/lib/s3_aggregator.py --jq-filter lib/pagestats.jq \
	--s3-prefix s3://$(S3_BUCKET_BBOXQA)/$(PROCESS_LABEL_BBOXQA)/$(RUN_ID_BBOXQA) \
	-o s3://$(S3_BUCKET_BBOXQA)/$(PROCESS_LABEL_BBOXQA)/$(RUN_ID_BBOXQA)__AGGREGATED_pagestats.jsonl.gz 

aggregate-iiif-errors:
	python cookbook/lib/s3_aggregator.py --jq-filter lib/iiif-errors.jq \
	--s3-prefix s3://$(S3_BUCKET_BBOXQA)/$(PROCESS_LABEL_BBOXQA)/$(RUN_ID_BBOXQA) \
	-o s3://$(S3_BUCKET_BBOXQA)/$(PROCESS_LABEL_BBOXQA)/$(RUN_ID_BBOXQA)__AGGREGATED_iiif-errors.jsonl.gz 

aggregate-page-dimensions:
	python cookbook/lib/s3_aggregator.py --jq-filter lib/image-dimensions.jq \
	--s3-prefix s3://$(S3_BUCKET_BBOXQA)/$(PROCESS_LABEL_BBOXQA)/$(RUN_ID_BBOXQA) \
	-o s3://$(S3_BUCKET_BBOXQA)/$(PROCESS_LABEL_BBOXQA)/$(RUN_ID_BBOXQA)__AGGREGATED_image-dimensions.jsonl.gz

aggregate: aggregate-pagestats aggregate-iiif-errors
 #python s3_aggregator.py -k ci_id ocrqa --s3-prefix s3://42-processed-data-final/ocrqa/ocrqa-ocrqa-wp_v1.0.6_v1-0-0/ -o 3://42-processed-data-final/ocrqa/ocrqa-ocrqa-wp_v1.0.6_v1-0-0__AGGREGATED.jsonl.gz 

help-aggregation::
	@echo "BBOXQA AGGREGATION:"
	@echo "  aggregate              # Run the default BBOXQA aggregations"
	@echo "  aggregate-pagestats    # Aggregate page statistics"
	@echo "  aggregate-iiif-errors  # Aggregate IIIF errors"
	@echo "  aggregate-page-dimensions # Aggregate page image dimensions"
