# Release Notes - v1.1.0

**Release Date:** November 4, 2025  
**Tag:** v1.1.0  
**Status:** Pre-release

## Overview

Version 1.1.0 represents a major expansion of the Impresso Make Cookbook, adding comprehensive support for multiple NLP processing pipelines, improved configuration management, and enhanced Python library utilities. This release introduces 70 file changes with over 11,000 lines of new code and documentation.

## 🎯 Major Features

### New Processing Pipelines

#### Language Identification

- **Complete language identification pipeline** (`processing_langident.mk`, `paths_langident.mk`, `sync_langident.mk`)
  - Multi-system language detection support (langid, langdetect, FastText, Lingua)
  - Three-stage processing: systems, statistics, and ensemble
  - Configurable format support (canonical and rebuilt)
  - Minimal text length thresholds for quality control
  - Provider-specific language boost options
  - **Work-in-progress (WIP) file management** for preventing concurrent processing across distributed machines
    - Optional WIP file creation and management on S3
    - Stale WIP file cleanup (configurable max age)
    - Process visibility with machine metadata
    - Automatic WIP removal after successful completion

#### OCR Quality Assessment

- **OCR quality assessment pipeline** (`processing_ocrqa.mk`, `paths_ocrqa.mk`, `sync_ocrqa.mk`)
  - Bloom filter-based quality checking
  - Multi-language support
  - HuggingFace integration for model management
  - Configurable minimum subtoken thresholds

#### Topic Modeling

- **Mallet-based topic modeling** (`processing_topics.mk`, `paths_topics.mk`, `sync_topics.mk`)
  - Integration with Mallet topic modeling toolkit
  - Java/JPype setup and configuration
  - Version-controlled model management
  - Configurable random seed for reproducibility

#### News Agencies Processing

- **News agencies data processing** (`processing_newsagencies.mk`, `paths_newsagencies.mk`, `sync_newsagencies.mk`)

#### Bounding Box Quality Assessment

- **Bounding box quality assessment** (`processing_bboxqa.mk`, `paths_bboxqa.mk`, `sync_bboxqa.mk`)
  - Statistics aggregation for bbox quality
  - Dedicated aggregator pipeline

### Python Library Enhancements

New comprehensive Python library (`lib/`) with installable package:

- **`common.py`** (674 lines): Core utilities for newspaper processing
- **`list_newspapers.py`** (680 lines): Newspaper discovery and listing
- **`local_to_s3.py`** (605 lines): Path conversion between local and S3
- **`s3_aggregator.py`** (400 lines): S3 data aggregation utilities
- **`s3_comparer.py`** (527 lines): S3 file comparison tools
- **`s3_compiler.py`** (693 lines): S3 data compilation
- **`s3_sampler.py`** (1,175 lines): S3 data sampling utilities
- **`s3_set_timestamp.py`** (608 lines): Timestamp management for S3
- **`s3_to_local_stamps.py`** (729 lines): Stamp file synchronization

Package can be installed via:

```bash
python3 -m pip install git+https://github.com/impresso/impresso-make-cookbook.git@v1.1.0#subdirectory=lib
```

### Build System Improvements

#### Configuration Management

- **`make_settings.mk`**: Core Make settings and shell configuration
- **`log.mk`** (115 lines): Comprehensive logging utilities with configurable log levels (DEBUG, INFO, WARNING, ERROR)
- **`comment_template.mk`** (97 lines): Standardized documentation templates
- **Template files** for easier customization:
  - `paths_TEMPLATE.mk`
  - `processing_TEMPLATE.mk`
  - `setup_TEMPLATE.mk`
  - `sync_TEMPLATE.mk`
  - `template-starter.mk`

#### Setup Automation

- **`setup_python.mk`** (84 lines): Python environment setup
- **`setup_aws.mk`** (80 lines): AWS CLI configuration
- **`setup_lingproc.mk`** (39 lines): Linguistic processing environment
- **`setup_ocrqa.mk`** (22 lines): OCR QA setup
- **`setup_topics.mk`** (50 lines): Topic modeling setup
- **`setup_newsagencies.mk`**: News agencies setup

#### Data Aggregation

- **`aggregators_langident.mk`**: Language identification statistics
- **`aggregators_bboxqa.mk`**: Bounding box QA statistics
- **`aggregators_lingproc.mk`** (227 lines): Linguistic processing aggregation with jq utilities
  - `lib/langident_stats.jq`: Language statistics extraction
  - `lib/pagestats.jq`: Page-level statistics

### Enhanced Documentation

- **Expanded README.md** (557 new lines):

  - Comprehensive build system structure documentation
  - Detailed processing workflow overview
  - Setup guide with dependencies
  - Extensive Makefile targets reference
  - Usage examples for common scenarios
  - Configuration and customization guide
  - Terminology and GNU Make concepts explanation
  - FAQ section

- **Configuration templates**:
  - `dotenv.sample`: Environment variable examples

## 🔧 Technical Improvements

### Provider Flag Unification

- Standardized provider organization flags to integer-based values for consistency
- Improved flag handling across language identification systems

### Language Identification Options

- Removed redundant default assignments to ensure user-supplied settings are properly respected
- Enhanced option handling for minimal text length thresholds

### S3 Bucket Configuration

- Updated S3 bucket variable assignments for improved flexibility
- Better separation between canonical, rebuilt, and processed data buckets

### Installation Scripts

- Enhanced `install_apt.sh`: Ubuntu/Debian package installation
- Enhanced `install_brew.sh`: macOS Homebrew installation

## 📦 Dependencies

New dependencies added to `requirements.txt` and `Pipfile`:

- Python 3.11+ support
- AWS CLI integration
- jq for JSON processing
- GNU parallel for distributed processing
- Java 17 for Mallet topic modeling

## 🔄 Migration Guide

### From v1.0.0 to v1.1.0

1. **Update Python dependencies:**

   ```bash
   pipenv install
   # or
   pip install -r requirements.txt
   ```

2. **Configure new environment variables** (see `dotenv.sample`):

   ```bash
   SE_ACCESS_KEY=your_access_key
   SE_SECRET_KEY=your_secret_key
   SE_HOST_URL=https://os.zhdk.cloud.switch.ch/
   ```

3. **Run new setup targets:**

   ```bash
   make setup-python-env
   make create-aws-config
   make setup
   ```

4. **For language identification:**

   ```bash
   make langident-target NEWSPAPER=your_newspaper

   # With WIP file management for distributed processing
   make langident-target NEWSPAPER=your_newspaper \
     LANGIDENT_WIP_ENABLED=1 LANGIDENT_WIP_MAX_AGE=2
   ```

5. **For OCR quality assessment:**
   ```bash
   make ocrqa-target NEWSPAPER=your_newspaper
   ```

## 🐛 Known Issues

- The repository uses shallow/grafted history, which may affect some git operations
- Some processing pipelines require specific external tools (Java, spaCy models, etc.)

## 📝 Configuration Changes

### New User-Configurable Variables

#### Language Identification

- `USE_CANONICAL`: Flag to use canonical format instead of rebuilt
- `LANGIDENT_LOGGING_LEVEL`: Logging level for langident processing
- `LANGIDENT_MINIMAL_TEXT_LENGTH_OPTION`: Default minimal text length
- `LANGIDENT_SYSTEMS_LIDS_OPTION`: Language identification systems to use
- `LANGIDENT_FORMAT_OPTION`: Input format selection
- `LANGIDENT_WIP_ENABLED`: Enable work-in-progress file management (default: disabled)
- `LANGIDENT_WIP_MAX_AGE`: Maximum age in hours for WIP files before considering them stale (default: 24)

#### OCR Quality Assessment

- `OCRQA_LANGUAGES_OPTION`: Languages for OCR assessment
- `OCRQA_BLOOMFILTERS_OPTION`: Bloom filter configuration
- `OCRQA_MIN_SUBTOKENS_OPTION`: Minimum subtokens threshold

#### Topic Modeling

- `MALLET_RANDOM_SEED`: Random seed for reproducibility
- `MODEL_VERSION_TOPICS`: Version identifier for topic models
- `LANG_TOPICS`: Language specification

#### Parallel Processing

- `PARALLEL_JOBS`: Maximum parallel jobs
- `COLLECTION_JOBS`: Number of parallel newspaper collections
- `NEWSPAPER_JOBS`: Jobs per newspaper
- `MAX_LOAD`: Maximum system load average

## 🔗 Links

- **Full Changelog**: https://github.com/impresso/impresso-make-cookbook/compare/v1.0.0...v1.1.0
- **Documentation**: See README.md for comprehensive usage guide
- **Issues**: https://github.com/impresso/impresso-make-cookbook/issues

## 👥 Contributors

- Simon Clematide (@simon-clematide)

## 📄 License

This software is licensed under the GNU Affero General Public License v3.0 or later.

---

For questions or issues, please visit the [GitHub repository](https://github.com/impresso/impresso-make-cookbook).
