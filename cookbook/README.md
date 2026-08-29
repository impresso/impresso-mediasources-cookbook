# Impresso Make-Based Offline (NLP) Processing Cookbook

Welcome to the Impresso Make-Based Offline (NLP) Processing Cookbook! This repository provides a comprehensive guide and set of tools for processing newspaper content. The build system leverages Makefiles to orchestrate complex workflows, ensuring efficient and scalable data processing. By utilizing S3 for data storage and local stamp files for tracking progress, this system supports distributed processing across multiple machines without conflicts.

## Table of Contents

- [Build System Structure](#build-system-structure)
- [Uploading to impresso S3 bucket](#uploading-to-impresso-s3-bucket)
- [Processing Workflow Overview](#processing-workflow-overview)
  - [Key Features](#key-features)
    - [Data Storage on S3](#data-storage-on-s3)
    - [Local Stamp Files](#local-stamp-files)
    - [Makefile and Build Dependencies](#makefile-and-build-dependencies)
    - [Running Local Commands](#running-local-commands)
    - [Uploading Results to S3](#uploading-results-to-s3)
    - [Handling Large Datasets on Small Machines](#handling-large-datasets-on-small-machines)
    - [Parallelization](#parallelization)
    - [Multi-Machine Build Isolation](#multi-machine-build-isolation)
- [Setup Guide](#setup-guide)
  - [Dependencies](#dependencies)
  - [Installation](#installation)
- [Makefile Targets](#makefile-targets)
- [Usage Examples](#usage-examples)
- [Contributing](#contributing)
- [License](#license)

## Cookbook Python Package

A miminal package with the minimal Python code that is common to most functionality
shared by processing pipelines in the cookbook can be installed with:

```bash
# install via pip
python3 -m pip install git+https://github.com/impresso/impresso-make-cookbook.git@main#subdirectory=lib

# or add the following to your Pipfile
impresso-cookbook = {git = "https://github.com/impresso/impresso-make-cookbook.git", ref = "main", subdirectory = "lib"}

```

## Build System Structure

The build system is organized into several make include files:

- `config.local.mk`: Local configuration overrides (not in the repository)
- `config.mk`: Main configuration file with default settings
- `cookbook/make_settings.mk`: Core make settings and shell configuration
- `cookbook/log.mk`: Logging utilities with configurable log levels
- `cookbook/setup.mk`: General setup targets and directory management
- `cookbook/sync.mk`: Data synchronization between S3 and local storage
- `cookbook/clean.mk`: Cleanup targets for build artifacts
- `cookbook/processing.mk`: Processing configuration and behavior settings
- `cookbook/main_targets.mk`: Core processing targets and parallelization
- `cookbook/newspaper_list.mk`: Newspaper list management and S3 discovery
- `cookbook/local_to_s3.mk`: Path conversion utilities between local and S3
- `cookbook/aws.mk`: AWS CLI configuration and testing

### Processing Pipeline Makefiles

- `cookbook/paths_*.mk`: Path definitions for different processing stages
  - `paths_canonical.mk`: Canonical newspaper content paths
  - `paths_rebuilt.mk`: Rebuilt newspaper content paths
  - `paths_lingproc.mk`: Linguistic processing paths
  - `paths_ocrqa.mk`: OCR quality assessment paths
  - `paths_langident.mk`: Language identification paths
  - `paths_topics.mk`: Topic modeling paths
  - `paths_bboxqa.mk`: Bounding box quality assessment paths

- `cookbook/processing_*.mk`: Processing targets for different NLP tasks
  - `processing_lingproc.mk`: Linguistic processing (POS tagging, NER)
  - `processing_ocrqa.mk`: OCR quality assessment
  - `processing_langident.mk`: Language identification
  - `processing_topics.mk`: Topic modeling with Mallet
  - `processing_bboxqa.mk`: Bounding box quality assessment

- `cookbook/sync_*.mk`: Data synchronization for different processing stages
  - `sync_canonical.mk`: Canonical content synchronization
  - `sync_rebuilt.mk`: Rebuilt content synchronization
  - `sync_lingproc.mk`: Linguistic processing data sync
  - `sync_ocrqa.mk`: OCR QA data synchronization
  - `sync_langident.mk`: Language identification data sync
  - `sync_topics.mk`: Topic modeling data synchronization
  - `sync_bboxqa.mk`: Bounding box QA data synchronization

- `cookbook/setup_*.mk`: Setup targets for different processing environments
  - `setup_python.mk`: Python environment setup
  - `setup_lingproc.mk`: Linguistic processing environment
  - `setup_ocrqa.mk`: OCR quality assessment setup
  - `setup_topics.mk`: Topic modeling environment setup
  - `setup_aws.mk`: AWS CLI setup and configuration

- `cookbook/aggregators_*.mk`: Data aggregation targets
  - `aggregators_langident.mk`: Language identification statistics
  - `aggregators_bboxqa.mk`: Bounding box QA statistics

### Integrating the Cookbook into Your Project

When using this cookbook in your repository (typically as a git submodule at `cookbook/`), follow these critical patterns in your root `Makefile`:

**Essential Include Order:**

1. **Load `cookbook/log.mk` FIRST** - provides logging functions used everywhere
2. Load `cookbook/help.mk` - help system
3. Define config and user variables with `$(call log.info, VARIABLE_NAME)`
4. Load `cookbook/make_settings.mk` - shell options and make settings
5. Load `cookbook/setup.mk` - general setup
6. Load domain-specific includes (`newspaper_list.mk`, `paths_*.mk`, `sync_*.mk`, `processing_*.mk`)
7. Load utilities (`local_to_s3.mk`)
8. Load repo-specific addons LAST

**Example minimal integration:**

```makefile
SHELL := /bin/bash

# Load logging FIRST
include cookbook/log.mk
include cookbook/help.mk

# Config with proper logging
CONFIG_LOCAL_MAKE ?= config.local.mk
  $(call log.info, CONFIG_LOCAL_MAKE)
-include $(CONFIG_LOCAL_MAKE)

# Core includes
include cookbook/make_settings.mk
include cookbook/setup.mk
include cookbook/newspaper_list.mk
include cookbook/local_to_s3.mk

# Repo-specific
include cookbook-repo-addons/my_processing.mk

.DEFAULT_GOAL := help

.PHONY: help
help::
	@echo "Usage: make <target>"
```

**Key patterns:**

- Use `$(call log.info, VAR_NAME)` instead of `$(info ...)` for variable logging
- Use `help::` (double colon) so addons can extend help
- Never define manual `log.info` or `log.debug` - use the functions from `log.mk`

See [AGENT.md](AGENT.md) for detailed integration patterns and common mistakes.

## Uploading to impresso S3 bucket

Ensure that the environment variables `SE_ACCESS_KEY` and `SE_SECRET_KEY` for access to the S3 impresso infrastructure are set, e.g., by setting them in a local `.env` file.

The build process uploads the processed data to the impresso S3 bucket.

## AWS CLI With Project-Local Config

Use AWS CLI with project-local config files so commands do not depend on global `~/.aws` settings.

Important distinction in this cookbook:

- Most data uploads in processing/sampling recipes are done with `python3 -m impresso_cookbook.local_to_s3`.
- AWS CLI is used mainly for setup, connectivity checks, bucket/prefix inspection, and occasional manual operations.
- Do not replace `local_to_s3` upload steps in recipes unless you explicitly want to change reliability/verification behavior.

### 1. Generate local AWS config files

From the repository root:

```bash
make create-aws-config
```

This uses `.env` values and writes:

- `.aws/config`
- `.aws/credentials`

### 2. Call AWS CLI with local config explicitly

```bash
AWS_CONFIG_FILE=.aws/config \
AWS_SHARED_CREDENTIALS_FILE=.aws/credentials \
aws s3 ls s3://140-processed-data-sandbox/
```

You can also point AWS CLI to any project-local config directory (not only `.aws`):

```bash
AWS_DIR=configs/aws
AWS_CONFIG_FILE="$AWS_DIR/config" \
AWS_SHARED_CREDENTIALS_FILE="$AWS_DIR/credentials" \
aws s3api head-bucket --bucket 140-processed-data-sandbox --endpoint-url "$SE_HOST_URL"
```

This is useful when running multiple environments side by side (dev/staging/prod) with separate credential files.

For S3-compatible endpoints, the endpoint is already written to `.aws/config` by `create-aws-config`.

Typical AWS CLI use in this repository:

- quick bucket/prefix listing (`aws s3 ls ...`)
- bucket existence/access checks (`aws s3api head-bucket ...`)
- manual diagnostics

Typical upload path in this repository:

- Make recipes call `python3 -m impresso_cookbook.local_to_s3 ...` for file uploads

### 3. Quick connectivity test via Make

```bash
make test-aws
```

### 4. Use with run-specific Make configs

When running with a project config file (for example `CFG=configs/config_sampling_RUN_ID.mk`), AWS CLI checks in Make recipes still use project-local credentials from `.env` and/or `.aws/*` (not global user config).

This is independent from recipe uploads, which continue to run through `local_to_s3.py`.

Example:

```bash
make sampling-langident-fr CFG=configs/config_sampling_RUN_ID.mk
```

### Notes

- If `aws` is missing, install it with:

```bash
make install-aws
```

- Keep `.aws/credentials` local to this repository and do not commit secrets.

## Processing Workflow Overview

This overview explains the impresso linguistic preprocessing pipeline, focusing on efficient data processing, distributed scalability, and minimizing interference between machines.

### Key Features

#### Data Storage on S3

All input and output data reside on S3, allowing multiple machines to access shared data without conflicts. Processing directly from S3 reduces the need for local storage.

#### Local Stamp Files

Local **stamp files** mirror S3 metadata, enabling machines to independently track and manage processing tasks without downloading full datasets. This prevents interference between machines, as builds are verified against S3 before processing starts, ensuring no overwrites or duplicate results.

**Stamp API v2 and Directory-Level Stamps:**

The cookbook uses `s3_to_local_stamps.py` with `--stamp-api v2` to create **directory-level stamps** rather than individual file stamps. This approach:

- **Groups files by directory**: Instead of creating one stamp per S3 object, v2 creates one stamp per directory (based on `--directory-level` parameter)
- **Tracks latest modification**: Each directory stamp reflects the most recent modification time of any file within that directory
- **Reduces filesystem overhead**: Fewer stamp files means faster Make dependency evaluation and less filesystem clutter
- **Enables efficient synchronization**: Make can determine if an entire directory needs updating by checking a single stamp file

**Stamp File Naming Convention:**

- **Files on S3**: Stamp files have the **same name** as the S3 object they represent
  - Example: `build.d/115-canonical-processed-final/langident/RUN_ID/BL/WTCH/WTCH-1828.jsonl.bz2` (stamp for S3 file)
- **Directories on S3**: Stamp files must have a `.stamp` extension to avoid conflicts with actual directories
  - Example: `build.d/112-canonical-final/BL/WTCH/pages.stamp` (stamp representing the `pages/` directory on S3)
  - Without `.stamp` extension, `mkdir` would fail when trying to create the directory

This convention prevents file/directory conflicts: when Make needs to create a directory (e.g., `issues/`), there's no conflict because the stamp file is named `issues.stamp`, not `issues`.

#### Makefile and Build Dependencies

The Makefile orchestrates the pipeline by defining independent targets and dependencies based on stamp files. Each machine maintains its local state, ensuring stateless and conflict-free builds.

#### Running Local Commands

Processing scripts operate independently, handling data in a randomized order. Inputs are read from S3, outputs are uploaded back to S3, and no synchronization is required between machines. Additional machines can join or leave without disrupting ongoing tasks.

#### Uploading Results to S3

Processed files are validated locally and uploaded to S3 with integrity checks (e.g., JSON schema validation and md5sum). Results are never overwritten, ensuring consistency even with concurrent processing.

#### Handling Large Datasets on Small Machines

By leveraging S3 and stamp files, machines with limited storage (e.g., 100GB) can process large datasets efficiently without downloading entire files.

#### Local vs. S3 File Separation

The build system maintains a critical separation between **local stamp files** (used by Make for dependency tracking) and **actual data files** (stored on S3):

- **Local Stamp Files**: Zero-byte timestamp files created on the local filesystem that mirror the S3 object structure. These files serve ONLY as Make dependency markers and never contain actual data.
- **S3 Data Files**: All actual input and output data is ultimately stored on S3. Python processing scripts read input from S3 and write output to local files, which are then uploaded to S3.
- **Path Conversion**: When a Make recipe needs to pass an input file path to a Python script, it uses `$(call LocalToS3,...)` to convert the local prerequisite path (which may be a stamp file) to an S3 URL for reading.
- **Processing Flow**:
  1. Input is read from S3 (using `LocalToS3` conversion)
  2. Output is written to local filesystem (processing can take hours; writing directly to S3 during long-running processes is unreliable)
  3. Local output is uploaded to S3 after processing completes
  4. Local output file is truncated to zero bytes with `--keep-timestamp-only`, preserving only its timestamp for Make's dependency tracking

**Why This Matters:**

This design ensures that:

1. Make can track dependencies efficiently using local filesystem timestamps
2. Machines don't need to store full copies of large datasets locally (only timestamp-only files)
3. Input is always read from authoritative S3 data, preventing stale reads from local stamp files
4. Output is validated locally before upload, then replaced with timestamp markers
5. Distributed processing works correctly even when local files are just timestamp markers

**Example Pattern:**

```make
# Correct: Convert local input prerequisite to S3 URL, write output locally
$(OUTPUT_FILE): $(INPUT_FILE)
    python3 -m some_processor --infile $(call LocalToS3,$<,'') --outfile $@
    python3 -m impresso_cookbook.local_to_s3 --upload $(call LocalToS3,$@,'') --keep-timestamp-only
```

**Never** pass input prerequisite `$<` or `$^` directly to Python scripts for reading data - these may be zero-byte stamp files. Always use `$(call LocalToS3,...)` to read from S3. Output files `$@` can be written directly to local paths, then uploaded.

#### Parallelization

- **Local Parallelization**: Each machine uses Make's parallel build feature to maximize CPU utilization.
- **Distributed Parallelization**: Machines process separate subsets of data independently (e.g., by newspaper or date range) and write results to S3 without coordination.
- **Collection Runs**: `make collection` runs the `newspaper` target for each selected newspaper. This avoids forced resync churn for every collection item while still letting each newspaper sync its local S3-derived stamps before processing.

#### Multi-Machine Build Isolation

- **Stateless Processing**: Scripts rely only on S3 and local configurations, avoiding shared state.
- **Custom Configurations**: Each machine uses local configuration files or environment variables to tailor processing behavior.
- **Online Output Guards**: Long-running recipes should check the target S3 object immediately before expensive processing. Local sync stamps are useful for Make dependency planning, but an online check catches work completed by another machine after the last local sync.
- **WIP Locks for Overlap**: When machines may process overlapping newspapers or years, use WIP-enabled recipes so only one worker starts a missing target. An existence-only check skips already completed output, but a WIP lock also covers the race where two workers start at nearly the same time.

#### Work-In-Progress (WIP) File Management

The cookbook supports optional **WIP file management** to prevent concurrent processing of the same files across multiple machines:

- **WIP Files**: Temporary marker files (`.wip`) created on S3 when processing begins
- **Concurrent Processing Prevention**: Before starting work, the system checks for existing WIP files to avoid duplicate processing
- **Stale Lock Cleanup**: WIP files older than a recipe-specific configurable age are automatically removed, preventing orphaned locks from crashed processes
- **Process Visibility**: WIP files contain metadata about the processing machine (hostname, IP address, username, PID, start time)
- **Automatic Cleanup**: WIP files are automatically removed after successful completion

**When to Use WIP Management:**

- Enable WIP for language identification when multiple machines might process overlapping datasets
- Enable WIP for expensive per-target processing where output may already exist on S3
- Particularly useful in distributed environments where coordination is difficult
- Can be disabled for faster processing when coordination is managed externally; check the processing fragment for each recipe's default
- Prefer `make newspaper` or `make collection` for long processing runs. Use `make all` when you explicitly want to force-refresh local sync state before processing one configured run.

** More WIP Explanations **

```
# === Work-In-Progress (WIP) File Management ===
#
# This processing pipeline implements WIP file management to prevent concurrent
# processing of the same data across distributed machines. The system uses marker
# files (.wip) on S3 to coordinate work and ensure only one process works on a
# given dataset at a time.
#
# Exit Code Convention:
#   0 - Success or skip (file exists, or WIP created successfully)
#   1 - Error condition (processing failed)
#   2 - WIP exists, skip processing (used to signal concurrent work in progress)
#
# Makefile Pattern for WIP Handling:
#   python3 -m impresso_cookbook.local_to_s3 \
#       --s3-file-exists $(call LocalToS3,$@) \
#       --create-wip --wip-max-age $(LANGIDENT_WIP_MAX_AGE) \
#       --log-level $(LANGIDENT_LOGGING_LEVEL) \
#       $@ $(call LocalToS3,$@) \
#   || { test $$? -eq 2 && exit 0; exit 1; } \
#   && ,
#
# The pattern above:
#   - Checks if output file already exists on S3 (skip if present)
#   - --create-wip automatically enables WIP checking (no need for separate --wip flag)
#   - Checks if a WIP file exists (exit 2 if fresh WIP found)
#   - Creates a new WIP file if none exists or if stale
#   - The || { test $$? -eq 2 && exit 0; exit 1; } converts exit code 2 to 0
#     for Make, allowing the target to be skipped without error
#   - The && , ensures the command sequence continues only on success
#
# WIP File Contents (JSON on S3):
#   - hostname: Machine running the process
#   - ip_address: IP address of the machine
#   - username: User running the process
#   - pid: Process ID
#   - start_time: ISO timestamp when processing started
#   - files: List of files being processed
#
# Configuration Variables:
#   LANGIDENT_WIP_ENABLED: Set to 1 to enable WIP management (default: 1)
#   LANGIDENT_WIP_MAX_AGE: Max age in hours for WIP files (default: 3)
#
# Stale WIP Handling:
#   If a WIP file is older than LANGIDENT_WIP_MAX_AGE, it's considered stale
#   and will be removed automatically, allowing processing to proceed. This
#   handles cases where processes crash or machines fail.
#
# WIP Removal:
#   The final ensemble stage uses --remove-wip to clean up the WIP file after
#   successful completion of all processing stages.
#
###############################################################################
```

**Configuration:**

```bash
# Enable WIP management for language identification
make langident-target LANGIDENT_WIP_ENABLED=1 LANGIDENT_WIP_MAX_AGE=2

# Enable WIP management for consolidated canonical issue generation
make consolidatedcanonical-target CONSOLIDATEDCANONICAL_WIP_ENABLED=1 CONSOLIDATEDCANONICAL_WIP_MAX_AGE=24

# Or set in your config file
LANGIDENT_WIP_ENABLED := 1
LANGIDENT_WIP_MAX_AGE := 2
CONSOLIDATEDCANONICAL_WIP_ENABLED := 1
CONSOLIDATEDCANONICAL_WIP_MAX_AGE := 24
```

## Setup Guide

### Dependencies

- Python 3.11
- AWS CLI
- Git
- Make, `remake`
- Additional tools: `git-lfs`, `coreutils`, `parallel`

### 📌 Terminology and Cookbook Documentation

| Case                                          | Recipe? | Our Comment Terminology      | **GNU Make Terminology**                                 |
| --------------------------------------------- | ------- | ---------------------------- | -------------------------------------------------------- |
| User-configurable variable (`?=`)             | ❌      | **USER-VARIABLE**            | **"Recursive Variable (User-Overridable)"**              |
| Internal computed variable (`:=`)             | ❌      | **VARIABLE**                 | **"Simply Expanded Variable"**                           |
| Transformation function (`define … endef`)    | ❌      | **FUNCTION**                 | **"Multiline Variable (Make Function)"**                 |
| Target without a recipe (`.PHONY`)            | ❌      | **TARGET**                   | **"Phony Target (Dependency-Only Target)"**              |
| Target with a recipe that creates a file      | ✅      | **FILE-RULE**                | **"File Target (Explicit Rule)"**                        |
| Target that creates a timestamp file          | ✅      | **STAMPED-FILE-RULE**        | **"File Target (Explicit Rule with Timestamp Purpose)"** |
| **Double-colon target with no recipe** (`::`) | ❌      | **DOUBLE-COLON-TARGET**      | **"Double-Colon Target (Dependency-Only Target)"**       |
| **Double-colon target with a recipe** (`::`)  | ✅      | **DOUBLE-COLON-TARGET-RULE** | **"Double-Colon Target (Explicit Rule)"**                |

---

### 🚀 Explanation of GNU Make Terms

- **Recursive Variable (User-Overridable)** → Defined using `?=`, allowing users to override it.
- **Simply Expanded Variable** → Defined using `:=`, evaluated only once.
- **Multiline Variable (Make Function)** → A `define … endef` construct that acts as a function or script snippet.
- **Phony Target (Dependency-Only Target)** → A `.PHONY` target that does not create an actual file.
- **File Target (Explicit Rule)** → A normal rule that produces a file.
- **File Target (Explicit Rule with Timestamp Purpose)** → A special case of an explicit rule where the file primarily serves as a timestamp.
- **Double-Colon Target (Dependency-Only Target)** → A dependency-only target using `::`, allowing multiple independent rules.
- **Double-Colon Target (Explicit Rule)** → A `::` target that executes independently from others of the same name.

### Installation

GNU Make 4+ is required. On macOS, the system `/usr/bin/make` is too old; use Homebrew GNU Make (`gmake`) unless your shell is already configured so `make` resolves to the Homebrew version.

1. **Clone the repository:**

   ```bash
   git clone https://github.com/impresso/impresso-make-cookbook.git
   cd impresso-make-cookbook
   ```

2. **Set up environment variables:**
   Create a `.env` file in the project root:

   ```bash
   SE_ACCESS_KEY=your_access_key
   SE_SECRET_KEY=your_secret_key
   SE_HOST_URL=https://os.zhdk.cloud.switch.ch/
   ```

3. **Install system dependencies:**

   ```bash
   # On Ubuntu/Debian
   sudo apt-get install -y make git-lfs parallel coreutils openjdk-17-jre-headless

   # On macOS
   brew install make git-lfs parallel coreutils openjdk@17
   ```

If `make --version` does not report GNU Make 4+, use `gmake` for the commands below.

4. **Set up Python environment:**

   ```bash
   make setup-python-env
   # This installs Python 3.11, pip, and pipenv
   ```

5. **Install Python dependencies:**

   ```bash
   pipenv install
   # or
   python3 -m pip install -r requirements.txt
   ```

6. **Configure AWS CLI:**

   ```bash
   make create-aws-config
   make test-aws
   ```

7. **Run initial setup:**
   ```bash
   make setup
   ```

## Using the Cookbook as a Git Submodule

The Impresso Make-Based Offline Processing Cookbook can be integrated into an existing project as a Git submodule. This setup is recommended when the cookbook is used as shared Make-based infrastructure across multiple repositories.

### Add the Submodule

From the root of your parent repository, run:

```bash
git submodule add https://github.com/impresso/impresso-make-cookbook.git cookbook
git submodule update --init --recursive
```

This clones the cookbook into the `cookbook/` directory and pins it to a specific commit.

### Include Cookbook Makefiles

In your top-level `Makefile`, include the required cookbook makefiles explicitly:

```make
# Core configuration
include cookbook/config.mk
include cookbook/make_settings.mk

# Logging and setup
include cookbook/log.mk
include cookbook/setup.mk

# Processing and main targets
include cookbook/processing.mk
include cookbook/main_targets.mk
```

Additional `cookbook/*.mk` files can be included as needed, depending on which processing stages are required (e.g. language identification, linguistic processing, OCR QA).

### Local Configuration Overrides

Local configuration should be placed in a file that is not tracked by Git, for example:

```make
# config.local.mk (not committed)
BUILD_DIR := build.d
LOGGING_LEVEL := INFO
```

Ensure this file is included before or alongside the cookbook configuration if overrides are needed.

### Updating the Submodule

To update the cookbook to a newer version:

```bash
cd cookbook
git fetch
git checkout main
git pull
cd ..
git add cookbook
git commit -m "Update impresso-make-cookbook submodule"
```

This makes cookbook updates explicit and reproducible across machines.

### Notes

- The cookbook is path-stable when used as a submodule; internal includes assume the `cookbook/` prefix.
- Build directories, stamp files, and S3 synchronization behavior are unaffected by submodule usage.
- The Python helper package in `lib/` can still be installed independently via `pip` if required.

## Makefile Targets

The cookbook provides several categories of makefile targets:

### Core Processing Targets

- `make help`: Display all available targets with descriptions
- `make setup`: Initialize environment and create necessary directories
- `make newspaper`: Process a single newspaper (uses NEWSPAPER variable)
- `make collection`: Process multiple newspapers in parallel
- `make all`: Force resync input/output, then process one configured run

For long distributed runs, prefer `make newspaper` or `make collection`. The
normal sync step prepares local dependency stamps, and WIP-enabled recipes do an
online S3 check immediately before expensive processing so they can skip output
that another machine already completed. Use `make all` when you intentionally
want to discard and rebuild local sync state first.

### Parallel Processing Control

The build system automatically detects CPU cores and configures parallel processing:

- `NPROC`: Automatically detected number of CPU cores
- `PARALLEL_JOBS`: Maximum parallel jobs (defaults to NPROC)
- `COLLECTION_JOBS`: Number of parallel newspaper collections (defaults to NPROC/2)
- `NEWSPAPER_JOBS`: Jobs per newspaper (defaults to PARALLEL_JOBS/COLLECTION_JOBS)
- `MAX_LOAD`: Maximum system load average for job scheduling

### Processing Pipeline Targets

#### Language Identification

- `make langident-target`: Run language identification pipeline
- `make impresso-lid-stage1a-target`: Initial language classification
- `make impresso-lid-stage1b-target`: Collect language statistics
- `make impresso-lid-stage2-target`: Final language decisions with ensemble

#### Linguistic Processing

- `make lingproc-target`: Run linguistic processing (POS tagging, NER)
- `make check-spacy-pipelines`: Validate spaCy model installations

#### OCR Quality Assessment

- `make ocrqa-target`: Run OCR quality assessment
- `make check-python-installation-hf`: Test HuggingFace Hub setup

#### Topic Modeling

- `make topics-target`: Run topic modeling with Mallet
- `make setup-topics`: Set up Java, Python checks, and local topic paths
- `make install-java`: Ensure a Java runtime is available for Mallet
- `make check-python-installation`: Test Java/JPype setup for Mallet

#### Bounding Box Quality Assessment

- `make bboxqa-target`: Run bounding box quality assessment

### Data Synchronization Targets

- `make sync`: Synchronize local input and output stamps from S3
- `make sync-input`: Synchronize input stamps from S3
- `make sync-output`: Synchronize output stamps from S3
- `make resync`: Force complete resynchronization
- `make resync-input`: Force input data resynchronization
- `make resync-output`: Force output data resynchronization

### Cleanup Targets

- `make clean-build`: Remove entire build directory
- `make clean-sync-input`: Remove synchronized input data
- `make clean-sync-output`: Remove synchronized output data
- `make clean-sync`: Remove all synchronized data

### Setup and Configuration Targets

- `make setup-python-env`: Install Python, pip, and pipenv
- `make create-aws-config`: Generate AWS configuration from .env
- `make test-aws`: Test AWS S3 connectivity
- `make newspaper-list-target`: Generate list of newspapers to process
- `make update-pip-requirements-file`: Update requirements.txt from Pipfile

### Aggregation Targets

- `make aggregate`: Generate aggregated statistics
- `make aggregate-pagestats`: Aggregate page-level statistics
- `make aggregate-iiif-errors`: Aggregate IIIF error statistics

### Testing and Validation Targets

- `make test-LocalToS3`: Test path conversion utilities
- `make check-parallel`: Verify GNU parallel installation
- `make test_debug_level`: Test logging configuration at different levels

## Usage Examples

### Basic Processing

```bash
# Process a single newspaper
make newspaper NEWSPAPER=actionfem

# Process with custom parallel settings
make newspaper NEWSPAPER=EZR PARALLEL_JOBS=4

# Process a specific processing stage
make lingproc-target NEWSPAPER=actionfem
```

### Parallel and Distributed Processing

```bash
# Process multiple newspapers using collection target
make collection

# Process with custom job limits
make collection COLLECTION_JOBS=4 MAX_LOAD=8

# Process with specific newspaper sorting
make collection NEWSPAPER_YEAR_SORTING=cat  # chronological order
make collection NEWSPAPER_YEAR_SORTING=shuf # random order

# Process using GNU parallel with custom settings
make collection COLLECTION_JOBS=6 NEWSPAPER_JOBS=2
```

### Data Management

```bash
# Sync specific dataset types
make sync-input-rebuilt NEWSPAPER=actionfem
make sync-output-lingproc NEWSPAPER=actionfem

# Force resync with fresh data
make resync NEWSPAPER=EZR

# Clean up specific processing outputs
make clean-sync-lingproc
make clean-sync-output
```

### Configuration and Environment

```bash
# Set up complete environment
make setup-python-env
make create-aws-config
make setup

# Test environment components
make test-aws
make check-spacy-pipelines
make check-python-installation

# Configure custom paths
make newspaper S3_BUCKET_CANONICAL=112-canonical-test BUILD_DIR=test.d
```

### Advanced Processing Options

```bash
# Language identification with custom models
make langident-target \
  LANGIDENT_IMPPRESSO_FASTTEXT_MODEL_OPTION=models/custom-lid.bin \
  LANGIDENT_STAGE1A_MINIMAL_TEXT_LENGTH_OPTION=150

# OCR quality assessment with specific languages
make ocrqa-target \
  OCRQA_LANGUAGES_OPTION="de fr en" \
  OCRQA_MIN_SUBTOKENS_OPTION="--min-subtokens 5"

# Topic modeling with custom Mallet seed
make topics-target \
  MALLET_RANDOM_SEED=123 \
  MODEL_VERSION_TOPICS=v3.0.0

# Linguistic processing with validation
make lingproc-target \
  LINGPROC_VALIDATE_OPTION=--validate \
  LOGGING_LEVEL=DEBUG

# Language identification with WIP file management
make langident-target \
  LANGIDENT_WIP_ENABLED=1 \
  LANGIDENT_WIP_MAX_AGE=2 \
  NEWSPAPER=actionfem
```

### Debugging and Monitoring

```bash
# Enable debug logging
make newspaper LOGGING_LEVEL=DEBUG

# Process with dry-run mode (no S3 uploads)
make lingproc-target PROCESSING_S3_OUTPUT_DRY_RUN=--s3-output-dry-run

# Monitor processing status
make status    # if implemented
make logs TARGET=lingproc-target   # if implemented

# Test specific components
make test-LocalToS3
make test_debug_level
```

### Production Deployment

```bash
# Full production run with optimal settings
make all \
  COLLECTION_JOBS=8 \
  MAX_LOAD=12 \
  NEWSPAPER_YEAR_SORTING=shuf \
  LOGGING_LEVEL=INFO

# Process specific newspaper subset
echo "actionfem EZR" > newspapers.txt
make collection NEWSPAPERS_TO_PROCESS_FILE=newspapers.txt
```

## Configuration and Customization

### Environment Variables

The cookbook uses several environment variables for configuration:

- `SE_ACCESS_KEY`: S3 access key for authentication
- `SE_SECRET_KEY`: S3 secret key for authentication
- `SE_HOST_URL`: S3 endpoint URL (defaults to `https://os.zhdk.cloud.switch.ch/`)

### Logging Configuration

The cookbook includes a sophisticated logging system with multiple levels:

- `LOGGING_LEVEL`: Set to `DEBUG`, `INFO`, `WARNING`, or `ERROR`
- Debug logging provides detailed information about variable values and processing steps
- All makefiles use consistent logging functions: `log.debug`, `log.info`, `log.warning`, `log.error`

```bash
# Enable debug logging for detailed output
make newspaper LOGGING_LEVEL=DEBUG

# Set to WARNING to reduce output
make collection LOGGING_LEVEL=WARNING
```

### Processing Configuration Variables

Key user-configurable variables (can be overridden):

#### Parallel Processing

- `PARALLEL_JOBS`: Maximum parallel jobs (auto-detected from CPU cores)
- `COLLECTION_JOBS`: Number of parallel newspaper collections
- `NEWSPAPER_JOBS`: Jobs per newspaper processing
- `MAX_LOAD`: Maximum system load average for job scheduling

#### Data Processing Behavior

- `PROCESSING_S3_OUTPUT_DRY_RUN`: Set to `--s3-output-dry-run` to prevent S3 uploads
- `PROCESSING_KEEP_TIMESTAMP_ONLY_OPTION`: Keep only timestamp files after S3 upload
- `PROCESSING_QUIT_IF_S3_OUTPUT_EXISTS_OPTION`: Skip processing if output exists on S3

#### Newspaper Processing

- `NEWSPAPER`: Target newspaper to process
- `NEWSPAPER_YEAR_SORTING`: Sort order (`shuf` for random, `cat` for chronological)
- `BUILD_DIR`: Local build directory (defaults to `build.d`)

#### Language Identification

- `LANGIDENT_LID_SYSTEMS_OPTION`: LID systems to use (e.g., `langid impresso_ft wp_ft`)
- `LANGIDENT_STAGE1A_MINIMAL_TEXT_LENGTH_OPTION`: Minimum text length for stage 1a
- `LANGIDENT_BOOST_FACTOR_OPTION`: Boost factor for language scoring
- `LANGIDENT_WIP_ENABLED`: Enable work-in-progress file management (set to `1` to enable)
- `LANGIDENT_WIP_MAX_AGE`: Maximum age in hours for WIP files before considering them stale (default: `24`)

#### OCR Quality Assessment

- `OCRQA_LANGUAGES_OPTION`: Languages for OCR QA (e.g., `de fr`)
- `OCRQA_BLOOMFILTERS_OPTION`: Bloom filter files for OCR assessment
- `OCRQA_MIN_SUBTOKENS_OPTION`: Minimum subtokens for processing

#### Topic Modeling

- `JAVA_PACKAGE_APT`: Java package to install on Debian/Ubuntu for Mallet runtime setup
- `JAVA_PACKAGE_BREW`: Java package to install with Homebrew for Mallet runtime setup
- `TOPICS_LOGGING_LEVEL`: Logging level for topic inference orchestration
- `TOPICS_MIN_P`: Minimum topic probability threshold emitted by the inferencer
- `TOPICS_LANGUAGES`: Space-separated language list passed to the inferencer
- `TOPICS_DE_CONFIG`: German topic-model config path
- `TOPICS_FR_CONFIG`: French topic-model config path
- `TOPICS_LB_CONFIG`: Luxembourgish topic-model config path
- `MALLET_RANDOM_SEED`: Random seed for Mallet topic modeling
- `MODEL_VERSION_TOPICS`: Version identifier for topic models
- `LANG_TOPICS`: Language specification for topic models

### Path Configuration

The cookbook uses a sophisticated path management system:

- Input paths: `paths_canonical.mk`, `paths_rebuilt.mk`
- Output paths: `paths_lingproc.mk`, `paths_ocrqa.mk`, `paths_topics.mk`, etc.
- Automatic conversion between local and S3 paths via `LocalToS3` function

### S3 Bucket Configuration

Different processing stages use different S3 buckets:

- `S3_BUCKET_CANONICAL`: Canonical newspaper content (e.g., `112-canonical-final`)
- `S3_BUCKET_REBUILT`: Rebuilt newspaper data (e.g., `22-rebuilt-final`)
- `S3_BUCKET_LINGPROC`: Linguistic processing outputs (e.g., `40-processed-data-sandbox`)
- `S3_BUCKET_TOPICS`: Topic modeling results (e.g., `41-processed-data-staging`)

## FAQ

### How to debug build process if a target can not be built?

- enable DEBUG mode: `export LOGGING_LEVEL=DEBUG`
- use the remake debugger to show the instantiated build rules:
  ```
  remake -x --debugger
  remake<0> info rules
  ```

## About Impresso

### Impresso project

[Impresso - Media Monitoring of the Past](https://impresso-project.ch) is an interdisciplinary research project that aims to develop and consolidate tools for processing and exploring large collections of media archives across modalities, time, languages and national borders. The first project (2017-2021) was funded by the Swiss National Science Foundation under grant No. [CRSII5_173719](http://p3.snf.ch/project-173719) and the second project (2023-2027) by the SNSF under grant No. [CRSII5_213585](https://data.snf.ch/grants/grant/213585) and the Luxembourg National Research Fund under grant No. 17498891.

### Copyright

Copyright (C) 2024 The Impresso team.

### License

This program is provided as open source under the [GNU Affero General Public License](https://github.com/impresso/impresso-pyindexation/blob/master/LICENSE) v3 or later.

---

<p align="center">
  <img src="https://github.com/impresso/impresso.github.io/blob/master/assets/images/3x1--Yellow-Impresso-Black-on-White--transparent.png?raw=true" width="350" alt="Impresso Project Logo"/>
</p>
