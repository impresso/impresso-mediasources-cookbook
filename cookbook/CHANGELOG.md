# Changelog

All notable changes to the Impresso Make Cookbook project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-04-22

### Added

#### Opportunistic S3 Orchestration
- `lib/s3_pipeline_support.py` with shared readiness and WIP-lock helpers for distributed pipeline stages
- `lib/manage_s3_wip.py` as a packaged CLI for acquiring and releasing S3 `.wip` locks

#### Sampling and Collection Processing
- Generic sampling orchestration in `sampling.mk`
- Rebuilt-content sampling workflow in `sampling_rebuilt.mk`
- Language-specific sampling workflow in `sampling_langident.mk`
- Collection-level jq aggregation utility in `lib/s3_collection_aggregator.py`
- Optional `SAMPLING_PARAMS_INFIX` support for encoding sampling hyperparameters in sampling run IDs

#### REOCR Pipeline Support
- `paths_reocr.mk` for REOCR path and run-ID conventions
- `processing_reocr.mk` for REOCR execution and upload orchestration
- `setup_reocr.mk` for REOCR setup wiring
- `sync_reocr.mk` for REOCR input/output synchronization

### Changed

#### Topic and Langident Processing
- `processing_topics.mk` now uses opportunistic S3 WIP lock management and exposes configurable topic-processing parameters
- `processing_langident.mk` now calls packaged module entrypoints for S3 WIP management
- `setup_topics.mk` now has clearer setup structure, Java package configuration, and local-path preparation
- `sync_topics.mk` now syncs topic stamps with improved logging, file filtering, and cleanup wiring

#### Aggregation and Sampling Behavior
- `lib/s3_aggregator.py` can now attach source locator metadata to JSON outputs
- `aggregators_langident.mk` now requests source metadata in aggregated outputs
- `lib/s3_compiler.py` now normalizes S3 prefixes to ensure a trailing slash
- `sampling_langident.mk` adds output-bucket accessibility checks and optional upload disabling

#### AWS and Documentation
- `aws.mk` now prints the `.env` variables needed to reuse repo-local AWS CLI config files
- `README.md` documents project-local AWS CLI config usage more explicitly
- `RELEASE_PROCESS.md` now requires release notes to be committed before tagging and publishing
- `newspaper_list.mk` uses improved fallback logic for `S3_PREFIX_NEWSPAPERS_TO_PROCESS_BUCKET`
- `.gitignore` now ignores local `.env` and `venv/` files
- `AGENT.md` documents repository structure and the expected submodule/helper usage model

### Fixed

- Updated bucket references to the processed-data sandbox naming used by the current sampling flows
- Removed an unnecessary `newspaper-list-target` dependency from setup wiring

### Technical Details

- 29 commits since `v1.3.1`
- 24 files changed
- 11 new files created
- 13 files modified
- 1,904 lines added, 100 lines removed

## [1.1.0] - 2025-11-04

### Added

#### Processing Pipelines
- Complete language identification pipeline with multi-system support
- OCR quality assessment pipeline with Bloom filters
- Mallet-based topic modeling pipeline with reproducibility controls
- News agencies data processing pipeline
- Bounding box quality assessment pipeline

#### Python Library
- Comprehensive Python library package (installable via pip)
- `common.py`: Core utilities for newspaper processing (674 lines)
- `list_newspapers.py`: Newspaper discovery and listing (680 lines)
- `local_to_s3.py`: Path conversion utilities (605 lines)
- `s3_aggregator.py`: S3 data aggregation (400 lines)
- `s3_comparer.py`: S3 file comparison tools (527 lines)
- `s3_compiler.py`: S3 data compilation (693 lines)
- `s3_sampler.py`: S3 data sampling utilities (1,175 lines)
- `s3_set_timestamp.py`: Timestamp management (608 lines)
- `s3_to_local_stamps.py`: Stamp file synchronization (729 lines)

#### Build System Features
- `make_settings.mk`: Core Make settings and shell configuration
- `log.mk`: Comprehensive logging with DEBUG/INFO/WARNING/ERROR levels (115 lines)
- `comment_template.mk`: Standardized documentation templates (97 lines)
- Template files for paths, processing, setup, and sync configurations
- Setup automation for Python, AWS, linguistic processing, OCR QA, and topics

#### Data Aggregation
- Language identification statistics aggregator
- Bounding box QA statistics aggregator
- Linguistic processing aggregator with jq utilities (227 lines)
- Page-level and language statistics extraction with jq

#### Documentation
- Expanded README.md with 557 new lines
- Build system structure documentation
- Processing workflow overview
- Setup guide with dependencies
- Makefile targets reference
- Usage examples and configuration guide
- GNU Make terminology explanation
- FAQ section
- `dotenv.sample`: Environment variable configuration template

### Changed
- Unified provider organization flags to integer-based values for consistency
- Updated S3 bucket variable assignments for improved flexibility
- Enhanced `install_apt.sh` for Ubuntu/Debian package installation
- Enhanced `install_brew.sh` for macOS Homebrew installation
- Improved Makefile structure with better documentation

### Fixed
- Removed redundant default assignment in language identification options to ensure user-supplied settings are respected

### Technical Details
- 70 files changed
- 11,243 lines added
- 50 new files created
- 18 files modified

## [1.0.0] - 2025-02-03

### Added
- Initial release of Impresso Make Cookbook
- Basic linguistic preprocessing pipeline
- Makefile-based build system
- S3 integration for data storage
- Local stamp files for progress tracking
- Basic setup and synchronization targets

---

## Version Numbering

This project follows [Semantic Versioning](https://semver.org/):
- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

## Release Types

- **Stable releases**: Fully tested and ready for production use
- **Pre-releases**: Feature-complete but may require additional testing

[1.1.0]: https://github.com/impresso/impresso-make-cookbook/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/impresso/impresso-make-cookbook/releases/tag/v1.0.0
[1.4.0]: https://github.com/impresso/impresso-make-cookbook/compare/v1.3.1...v1.4.0
