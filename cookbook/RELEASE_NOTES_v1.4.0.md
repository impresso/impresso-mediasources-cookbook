# Release Notes: v1.4.0

**Release Date:** 2026-04-22  
**Comparison:** [v1.3.1...v1.4.0](https://github.com/impresso/impresso-make-cookbook/compare/v1.3.1...v1.4.0)

## Overview

Version 1.4.0 expands the cookbook’s reusable orchestration layer with packaged S3 WIP-lock helpers for opportunistic distributed processing, topic-processing integration with that lock model, new sampling flows, a collection-level S3 aggregator, and a first REOCR cookbook module.

This release is centered on making the cookbook more self-contained as a shared helper layer: the WIP orchestration logic now lives in packaged helper modules, topic and langident processing use those helpers, and the surrounding setup, sync, AWS, and release documentation has been tightened accordingly.

## What's New

### 🆕 New Features

#### Opportunistic S3 WIP Orchestration

- **New packaged WIP helper module** in `lib/s3_pipeline_support.py`
  - Provides shared readiness checks and S3 `.wip` lock handling for distributed stages
  - Exposes common exit semantics for “not ready”, “output exists”, and “locked by another worker”

- **New packaged CLI** in `lib/manage_s3_wip.py`
  - Supports `acquire` and `release` commands
  - Is callable as `python3 -m impresso_cookbook.manage_s3_wip`
  - Makes WIP coordination available without relying on project-local standalone scripts

#### Sampling Workflows

- **New generic sampling entrypoint** in `sampling.mk`
  - Introduces a reusable `sample-target`
  - Provides common sampling defaults such as log level, random seed, and sample rate

- **New rebuilt sampling workflow** in `sampling_rebuilt.mk`
  - Samples IDs from rebuilt S3 inputs
  - Compiles sampled IDs back into full records
  - Uploads both sampled IDs and compiled outputs to S3

- **New language-identification sampling workflow** in `sampling_langident.mk`
  - Selects language-specific records from aggregated langident outputs
  - Supports per-language OCRQA and minimum-length thresholds
  - Compiles selected IDs back into fulltext records
  - Supports output bucket checks and optional upload suppression for local-only runs

- **Configurable sampling run-ID encoding**
  - Adds `SAMPLING_PARAMS_INFIX` to encode sampling hyperparameters directly in run IDs
  - Makes sampling outputs easier to compare and trace across runs

#### Collection-Level Aggregation

- **New `lib/s3_collection_aggregator.py` utility**
  - Streams all JSON objects from matching S3 JSONL inputs into a single jq invocation
  - Supports collection-level jq workflows that need `inputs` rather than per-record transforms
  - Works with local or S3 outputs and optional log files

#### REOCR Cookbook Support

- **New REOCR pipeline fragments**
  - `paths_reocr.mk`
  - `processing_reocr.mk`
  - `setup_reocr.mk`
  - `sync_reocr.mk`

- These fragments provide cookbook-side wiring for REOCR page processing, done markers, logs, and synchronized S3/local path conventions.

### 🔧 Improvements

#### Topic and Langident Orchestration

- **Topic processing now supports S3 WIP lock management**
  - `processing_topics.mk` can now acquire and release S3 WIP locks before and after inference
  - Adds topic-specific controls including:
    - `TOPICS_WIP_ENABLED`
    - `TOPICS_WIP_MAX_AGE`
    - `TOPICS_UPLOAD_IF_NEWER_OPTION`
    - `TOPICS_FORCE_OVERWRITE_OPTION`
    - configurable topic languages, configs, and minimum probability

- **Langident processing now uses packaged module entrypoints**
  - `processing_langident.mk` now calls `python3 -m impresso_cookbook.manage_s3_wip`
  - Keeps the opportunistic WIP behavior while moving the implementation into the helper package

- **Topic setup and sync were refined**
  - `setup_topics.mk` now has a clearer setup structure and configurable Java package names
  - `sync_topics.mk` now syncs only the expected topic-side file types with improved logging and cleanup behavior

#### Source Metadata and S3 Handling

- **Source locator metadata in aggregation outputs**
  - `lib/s3_aggregator.py` can now inject `source_file`, `source_bucket`, `source_key`, `provider`, `newspaper`, and `source_path_segment`
  - `aggregators_langident.mk` enables that metadata in langident aggregation output

- **Normalized S3 prefix handling**
  - `lib/s3_compiler.py` now normalizes the S3 prefix to ensure trailing-slash behavior is consistent
  - Reduces path-joining ambiguity during record compilation

#### AWS CLI Workflow

- **Improved local AWS config guidance**
  - `aws.mk` now prints the `.env` snippet needed after `make create-aws-config`
  - `README.md` now documents project-local AWS CLI config usage and its relationship to `local_to_s3`

#### Repository Hygiene and Documentation

- `.gitignore` now ignores `.env` and `venv/`
- `AGENT.md` documents repository structure, operational assumptions, and the cookbook’s expected role as a shared helper/submodule
- `RELEASE_PROCESS.md` now makes committed release notes part of the normal tagging workflow
- `newspaper_list.mk` improves fallback handling for `S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET`

### 🐛 Bug Fixes

- **Bucket naming aligned with current sandbox usage**
  - Updated bucket references to the processed-data sandbox naming used by the new sampling workflows

- **Setup dependency cleanup**
  - Removed an unnecessary `newspaper-list-target` dependency from setup wiring

### ⚠️ Breaking Changes

No breaking changes are intended in this release. Existing consumers should be able to adopt `v1.4.0` without changing established pipeline contracts.

### 🔄 Migration Guide

For most users, upgrading is straightforward:

1. Update the cookbook reference to `v1.4.0`.
2. If you install the helper package directly, use the `v1.4.0` tag in the `lib/` subdirectory install URL.
3. If you use repo-local AWS CLI config, consider adopting the documented `.env` variables:
   - `AWS_CONFIG_FILE=.aws/config`
   - `AWS_SHARED_CREDENTIALS_FILE=.aws/credentials`
4. If you rely on topic processing, review the new topic-specific orchestration variables in `processing_topics.mk`, especially the WIP and overwrite controls.
5. For new sampling flows, choose whether outputs should be uploaded immediately or kept local with `LANGIDENT_UPLOAD_ENABLED=0`.

### 🐛 Known Issues

- GNU Make 4.0+ is still required; default macOS `/usr/bin/make` is too old.
- Many targets still require live S3 credentials and network access to exercise fully.
- Some historical documentation still refers to `cookbook/...` paths even though this checkout stores the `*.mk` files at repository root.

## Files Changed

### New Files (11)

- `AGENT.md`
- `lib/manage_s3_wip.py`
- `lib/s3_collection_aggregator.py`
- `lib/s3_pipeline_support.py`
- `paths_reocr.mk`
- `processing_reocr.mk`
- `sampling.mk`
- `sampling_langident.mk`
- `sampling_rebuilt.mk`
- `setup_reocr.mk`
- `sync_reocr.mk`

### Modified Files (13)

- `.gitignore`
- `README.md`
- `RELEASE_PROCESS.md`
- `aggregators_langident.mk`
- `aws.mk`
- `lib/s3_aggregator.py`
- `lib/s3_compiler.py`
- `newspaper_list.mk`
- `processing_langident.mk`
- `processing_topics.mk`
- `setup_lingproc.mk`
- `setup_topics.mk`
- `sync_topics.mk`

## Statistics

- **29 commits** between `v1.3.1` and `v1.4.0`
- **24 files changed**
- **11 new files** added
- **13 files** modified
- **1,904 insertions**, **100 deletions**

## Contributors

This release includes contributions by Simon Clematide focused on extending the cookbook’s reusable orchestration layer for sampling, aggregation, and REOCR support.

---

**Full Changelog:** [v1.3.1...v1.4.0](https://github.com/impresso/impresso-make-cookbook/compare/v1.3.1...v1.4.0)
