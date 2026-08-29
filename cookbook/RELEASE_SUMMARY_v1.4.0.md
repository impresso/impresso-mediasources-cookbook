# v1.4.0 Release Summary

## Highlights

🔒 **Packaged S3 WIP Orchestration** - New helper modules for opportunistic distributed locking and readiness checks  
🧠 **Topics + Langident Integration** - Topic processing now uses S3 WIP locking, and langident uses packaged WIP entrypoints  
🧪 **New Sampling Workflows** - Generic sampling hooks plus rebuilt and langident-specific sampling pipelines  
📚 **Collection Aggregation** - New `s3_collection_aggregator.py` for jq filters that operate on whole collections  
🔎 **REOCR Cookbook Support** - New reusable make fragments for REOCR processing and synchronization

## New Features

- Packaged WIP helpers in `lib/s3_pipeline_support.py`
- Packaged WIP CLI in `lib/manage_s3_wip.py`
- Generic sampling orchestration in `sampling.mk`
- Rebuilt sampling pipeline in `sampling_rebuilt.mk`
- Language-specific langident sampling pipeline in `sampling_langident.mk`
- `SAMPLING_PARAMS_INFIX` for traceable run-ID encoding
- Collection-level jq aggregation in `lib/s3_collection_aggregator.py`
- REOCR support via `paths_reocr.mk`, `processing_reocr.mk`, `setup_reocr.mk`, and `sync_reocr.mk`

## Improvements

- `processing_topics.mk` now supports S3 WIP lock management and configurable topic inference parameters
- `processing_langident.mk` now uses packaged WIP module entrypoints
- `setup_topics.mk` and `sync_topics.mk` were refined for Java/runtime setup and topic stamp synchronization
- Source metadata can be added to aggregated JSON outputs
- `s3_compiler.py` now normalizes S3 prefixes consistently
- `aws.mk`, `README.md`, and `RELEASE_PROCESS.md` improve AWS and release workflow guidance
- `.gitignore` now ignores local `.env` and `venv/`
- `AGENT.md` documents the cookbook’s shared-helper/submodule role

## Fixes

- Updated bucket references to current processed-data sandbox naming
- Removed an unnecessary setup dependency on `newspaper-list-target`

## Technical Details

- **29 commits** | **24 files changed** | **11 new** | **13 modified**
- No intended breaking changes

**Full Changelog:** https://github.com/impresso/impresso-make-cookbook/compare/v1.3.1...v1.4.0
