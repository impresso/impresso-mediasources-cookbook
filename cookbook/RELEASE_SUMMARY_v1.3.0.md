# v1.3.0 Release Summary

## Highlights

🆕 **New Content Item Classification Pipeline** - Complete infrastructure for content item classification  
⬆️ **Force Upload Controls** - Granular control for re-uploading Stage 1, 2, and 3 files to S3  
🚀 **Language ID Cache Warming** - Pre-load Hugging Face models for faster distributed processing  
📊 **Enhanced Statistics** - Floret statistics aggregation and upload tracking

## New Features

- Content item classification pipeline with full setup/processing/sync support
- Force upload options for Stage 1, Stage 2, and Stage 3 files
- Setup script (`setup_langident.py`) for warming Hugging Face caches
- Floret statistics aggregation in language identification
- `--max-doc-length` option for linguistic processing
- `have_same_md5` utility function for file integrity checks
- Output file option for newspaper listing tool

## Improvements

- Streamlined WIP management with cleaner script-based approach
- Renamed cache option for clarity (local-only loading)
- Enhanced consolidatedcanonical sync with per-file mode and cleanup
- Timestamp-based S3 upload decisions with statistics tracking
- Fixed `NEWSPAPER_JOBS` calculation (minimum clamped to 1)
- Logarithmic thresholds for improved grouping logic
- Refactored collection target for better parallel execution

## Bug Fixes

- Regex patterns now support underscores in newspaper names
- Fixed target file rule in template-starter.mk
- Collection field now active in langident_stats.jq
- Fixed SHELL variable assignment and logging
- Fixed git version retrieval

## Technical Details

- **25 commits** | **24 files changed** | **6 new** | **18 modified**
- No breaking changes - fully backward compatible

**Full Changelog:** https://github.com/impresso/impresso-make-cookbook/compare/v1.2.0...v1.3.0
