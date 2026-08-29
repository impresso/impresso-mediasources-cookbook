# Configuration for S3 path suffix:
# mediasources/mediasources-ner-mmbert-impresso-mediasources-ner_v2-0-0_v1-0-0

MODEL_ID_MEDIASOURCES ?= mmbert-impresso-mediasources-ner_v2-0-0
HF_MODEL_MEDIASOURCES ?= impresso-project/mmbert-impresso-mediasources-ner
HF_MODEL_REVISION_MEDIASOURCES ?= v2.0.0

RUN_VERSION_MEDIASOURCES ?= v1-0-0
S3_BUCKET_MEDIASOURCES ?= 141-processed-data-staging

BATCH_SIZE_MEDIASOURCES ?= 32
OUTER_BATCH_SIZE_MEDIASOURCES ?= 4096
