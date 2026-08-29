# Release Notes: v1.3.0

**Release Date:** 2026-04-09  
**Comparison:** [v1.2.0...v1.3.0](https://github.com/impresso/impresso-make-cookbook/compare/v1.2.0...v1.3.0)

## Overview

Version 1.3.0 introduces significant enhancements to processing control, cache management, and pipeline capabilities. This release adds a new content item classification pipeline, improves resource management, and provides better control over S3 upload behavior with force-upload options for all processing stages.

## What's New

### 🆕 New Features

#### Content Item Classification Pipeline

- **New pipeline** for content item classification with complete setup, processing, and sync infrastructure
- Added `paths_content_item_classification.mk`, `processing_content_item_classification.mk`, `setup_content_item_classification.mk`, and `sync_content_item_classification.mk`
- Extends the cookbook's capabilities for advanced content analysis

#### Force Upload Controls

- **Force upload options for Stage 1, Stage 2, and Stage 3 files** to S3
- Enables reprocessing and re-uploading of data at any stage without manual intervention
- Useful for correcting data issues or updating processing results

#### Language Identification Enhancements

- **Setup script for warming Hugging Face caches** in language identification (`setup_langident.py`)
- Pre-loads models to reduce cold-start latency in distributed processing
- Improved handling of ensemble file dependencies with clearer comments and logic
- **Floret statistics aggregation** added to `aggregators_langident.mk`

#### Linguistic Processing Improvements

- **`--max-doc-length` option** for linguistic processing script
- Allows control over maximum document length for processing optimization
- Helps manage memory usage for large documents

#### Utility Enhancements

- **`have_same_md5` utility function** added to module exports
- Simplifies file integrity checking across the codebase
- **Output file option** for newspaper listing tool (`list_newspapers.py`)
- Enables redirection of newspaper lists to custom file locations

### 🔧 Improvements

#### WIP (Work-In-Progress) Management

- **Streamlined WIP management** by replacing legacy logic with new script calls
- Cleaner, more maintainable codebase for handling distributed processing locks

#### Cache and Data Loading

- **Renamed cache option** to clarify it loads from local files only
- Reduces confusion about data source when using cached data
- Improved transparency in processing workflows

#### Sync and Upload Behavior

- **Enhanced sync behavior** for consolidatedcanonical processing with per-file mode
- Improved cleanup logic for better resource management
- **S3 upload behavior based on timestamps** for intelligent upload decisions
- **Upload statistics tracking and summary logging** for better visibility into sync operations

#### Resource Management

- **Updated `NEWSPAPER_JOBS` calculation** to clamp at least to 1
- Prevents edge cases where job count could be zero
- Improved help documentation for parallel job configuration
- **Refactored collection target** for better parallel job execution and logging

#### Code Quality

- **Improved comments and suffix handling** in `LocalToS3` function
- Better documentation throughout Makefiles
- **Updated grouping logic to use logarithmic thresholds**
- More flexible and scalable data organization

### 🐛 Bug Fixes

- **Fixed regex patterns** to allow underscores in newspaper names
  - Supports broader range of newspaper naming conventions
  - Prevents processing failures for newspapers with underscores in IDs

- **Corrected target file rule** for processing CLI file in `template-starter.mk`
  - Ensures proper dependency resolution

- **Fixed collection field** in `langident_stats.jq` for data aggregation
  - Previously commented out, now properly included

- **Fixed SHELL variable assignment** and enhanced logging for linguistic processing settings
  - Ensures consistent shell behavior across environments

- **Fixed git version retrieval and logging**
  - Proper version tracking for reproducibility

### 🔄 Refactoring

- **Removed deprecated extract-tokens targets** and associated debug logs
  - Cleaner codebase with removal of obsolete functionality

- **Updated clean-sync target** to use double-colon syntax
  - Improved clarity and maintainability

- **Enhanced comments** throughout codebase for better maintainability
  - Particularly in language identification and ensemble handling

### 📚 Documentation

- **Git submodule integration documentation**
  - Clearer guidance on using cookbook as a submodule in other projects

## Files Changed

### New Files (6)

- `paths_content_item_classification.mk`
- `processing_content_item_classification.mk`
- `setup_content_item_classification.mk`
- `setup_langident.mk`
- `setup_langident.py`
- `sync_content_item_classification.mk`

### Modified Files (18)

- `README.md` - Documentation updates
- `aggregators_langident.mk` - Floret statistics aggregation
- `aggregators_lingproc.mk` - Enhancements
- `lib/__init__.py` - Utility exports
- `lib/langident_stats.jq` - Collection field fix
- `lib/list_newspapers.py` - Output file option
- `lib/local_to_s3.py` - Improved comments and suffix handling
- `lib/s3_compiler.py` - Enhancements
- `local_to_s3.mk` - LocalToS3 improvements
- `main_targets.mk` - Collection target refactoring
- `make_settings.mk` - NEWSPAPER_JOBS calculation fix
- `newspaper_list.mk` - Updates
- `processing.mk` - General improvements
- `processing_consolidatedcanonical.mk` - Sync behavior updates
- `processing_langident.mk` - Setup and cache enhancements
- `processing_lingproc.mk` - Max-doc-length option
- `sync_consolidatedcanonical.mk` - Per-file mode and cleanup
- `template-starter.mk` - Target file rule fix

## Migration Notes

### For Users

No breaking changes. All existing workflows should continue to work as before.

**Optional Enhancements:**

- Consider using new force-upload options if you need to reprocess data
- Use `setup_langident.py` to pre-warm caches for faster distributed processing
- Leverage `--max-doc-length` option if processing large documents

### For Developers

- If using `LocalToS3` function, review improved comments for better understanding
- WIP management now uses new script calls - update any custom extensions
- Collection field in langident_stats.jq is now active - ensure downstream processes handle it

## Statistics

- **25 commits** between v1.2.0 and v1.3.0
- **24 files changed**
- **6 new files** added
- **18 files** modified

## Contributors

This release includes contributions from the Impresso team working on enhanced processing capabilities, better resource management, and improved code quality.

---

**Full Changelog:** [v1.2.0...v1.3.0](https://github.com/impresso/impresso-make-cookbook/compare/v1.2.0...v1.3.0)
