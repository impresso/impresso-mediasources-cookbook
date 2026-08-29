# AGENT.md

## Purpose

This repository is the Impresso make-based processing cookbook. Its normal role is to be vendored or added as a shared helper, typically as a git submodule inside another processing repository.

It is not primarily a standalone product repository. It exists to abstract common GNU Make orchestration patterns, shared S3/stamp-file workflows, and small reusable Python helpers that other repositories compose into their own pipelines.

The core model is:

- inputs and outputs live on S3
- local files under `build.d/` are mostly dependency markers, stamps, logs, or transient outputs
- Make targets define synchronization, processing, aggregation, and upload behavior
- Python helpers under `lib/` provide the shared S3/stamp/upload utilities used by the recipes

## How It Is Usually Used

The expected integration model is:

- another repository owns the actual processing project
- this repository is included as a shared cookbook/helper layer
- the parent repository includes or reuses these `*.mk` fragments
- the parent repository defines the project-specific pipeline wiring, configs, scripts, and execution entrypoints

Some files here, such as the root `Makefile`, are examples or local wiring for this checkout, but the lasting value of the repository is the reusable make fragments and helper Python code.

## Repository Layout

- `Makefile`: one concrete/local entrypoint example for wiring a processing stack
- `*.mk`: reusable make fragments for setup, sync, path conventions, processing, sampling, and aggregation
- `lib/`: minimal Python package `impresso_cookbook` plus helper scripts
- `README.md`: high-level workflow and operational background
- `CHANGELOG.md`, `RELEASE_PROCESS.md`, `RELEASE_NOTES_*.md`: release documentation
- `dotenv.sample`: template for local `.env`

Important: some documentation and recipes still refer to paths like `cookbook/...`. That reflects the intended embedded/submodule usage pattern. In this checkout, the `.mk` files are at repository root and the Python package lives in `lib/`.

## Tooling And Environment

- GNU Make 4.0+ is required. On macOS, `/usr/bin/make` is too old (`3.81`) and fails immediately.
- Python packaging is split between:
  - root `Pipfile` / `requirements.txt`
  - `lib/pyproject.toml` for the installable `impresso_cookbook` package
- AWS/S3 access is configured from a local `.env` file and optional repo-local `.aws/` files.

If you need to run Make successfully on macOS, prefer Homebrew GNU Make (`gmake`) or another GNU Make 4+ binary.

## Main Concepts

### 1. Sync vs processing

Generic orchestration entrypoints are defined in shared fragments:

- `sync`, `sync-input`, `sync-output`, `resync-input`, `resync-output`, `resync`
- `processing-target`
- `newspaper`, `all`, `collection`

Concrete pipeline fragments bind those abstract targets with double-colon rules. Parent repositories are expected to compose these fragments into project-specific entrypoints. For example, `processing_lingproc.mk` attaches `processing-target :: lingproc-target`.

### 2. Stamp files

The repository relies heavily on local stamp files that mirror S3 object structure.

- per-file sync creates local placeholders matching remote object names
- per-directory sync creates `.stamp` files for directories
- these are Make dependency markers, not canonical data files

Do not casually replace stamp-based flows with normal file copies; a lot of dependency logic assumes the current stamp behavior.

### 3. S3 upload path

The normal upload mechanism is `python3 -m impresso_cookbook.local_to_s3`, not raw `aws s3 cp`.

AWS CLI is mainly used for:

- setup
- connectivity checks
- manual inspection/diagnostics

### 4. Makefile Integration Patterns

When integrating the cookbook into a parent repository's Makefile, follow these **critical** patterns:

#### Include Order (MANDATORY)

The include order matters because Make processes includes sequentially. Always use this order:

```makefile
# 1. FIRST: Load logging functions
include cookbook/log.mk

# 2. Load help system
include cookbook/help.mk

# 3. CONFIG_LOCAL_MAKE with proper logging
CONFIG_LOCAL_MAKE ?= config.local.mk
ifdef CFG
  CONFIG_LOCAL_MAKE := $(CFG)
  $(info Overriding CONFIG_LOCAL_MAKE to $(CONFIG_LOCAL_MAKE) from CFG variable)
else
  $(call log.info, CONFIG_LOCAL_MAKE)
endif
-include $(CONFIG_LOCAL_MAKE)

# 4. User variables with logging
LOGGING_LEVEL ?= INFO
  $(call log.info, LOGGING_LEVEL)

BUILD_DIR ?= build.d
  $(call log.info, BUILD_DIR)

# 5. Load shared make settings
include cookbook/make_settings.mk

# 6. Load general setup
include cookbook/setup.mk

# 7. Load domain-specific includes (paths, sync, processing)
include cookbook/newspaper_list.mk
include cookbook/paths_*.mk
include cookbook/sync_*.mk
include cookbook/processing_*.mk

# 8. Load utilities
include cookbook/local_to_s3.mk

# 9. LAST: Repo-specific addons
include cookbook-repo-addons/*.mk
```

**Why this order matters:**

- `log.mk` must be first so `$(call log.info, ...)` works in subsequent includes
- `help.mk` early so help targets can be extended with `::`
- `make_settings.mk` before any processing rules (sets shell options)
- Domain includes before repo addons (allows addons to override/extend)

#### Variable Logging Pattern

**WRONG:**

```makefile
BUILD_DIR ?= build.d
$(info BUILD_DIR=$(BUILD_DIR))
```

**CORRECT:**

```makefile
BUILD_DIR ?= build.d
  $(call log.info, BUILD_DIR)
```

The `log.info` function respects `LOGGING_LEVEL` and provides consistent formatting.

#### Help Target Extensibility

**WRONG:**

```makefile
.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo "Targets:"
	@echo "  foo    # Do foo"
```

**CORRECT:**

```makefile
.PHONY: help
help::
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Main Targets:"
	@echo "  foo    # Do foo"
	@echo ""
```

Use `help::` (double colon) so addon makefiles can extend help with their own sections.

#### Section Markers

Use consistent section markers for readability:

```makefile
###############################################################################
# Top-level project description
###############################################################################

###
# SECTION NAME
#------------------------------------------------------------------------------

# Include or define targets here
```

#### Common Integration Mistakes

1. **Missing `log.mk` include** → `$(call log.info, ...)` fails silently or errors
2. **Loading `log.mk` too late** → Early variable definitions don't log properly
3. **Single-colon help target** → Addons can't extend help
4. \*\*Manual logging instead of `$(call log.info, ...)` → Ignores `LOGGING_LEVEL`
5. **Wrong include order** → Dependency errors, undefined functions

#### Minimal Working Example

```makefile
###############################################################################
# My Processing Pipeline Makefile
###############################################################################

SHELL := /bin/bash

# Load logging FIRST
include cookbook/log.mk

# Load help system
include cookbook/help.mk

# Config with proper logging
CONFIG_LOCAL_MAKE ?= config.local.mk
  $(call log.info, CONFIG_LOCAL_MAKE)
-include $(CONFIG_LOCAL_MAKE)

# User variables
BUILD_DIR ?= build.d
  $(call log.info, BUILD_DIR)

# Core includes
include cookbook/make_settings.mk
include cookbook/setup.mk
include cookbook/newspaper_list.mk
include cookbook/local_to_s3.mk

# Project-specific
include cookbook-repo-addons/my_processing.mk

.DEFAULT_GOAL := help

.PHONY: help
help::
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
```

This pattern ensures all cookbook features work correctly and addon makefiles can extend the build system safely.

## Operational Conventions

- `BUILD_DIR ?= build.d`
- local credentials are expected in `.env`
- `create-aws-config` writes `.aws/config` and `.aws/credentials`
- `GIT_VERSION` is derived from `git describe --tags --always` and propagated into outputs
- Make recipes run with strict shell settings via `make_settings.mk`
- parallel collection runs use GNU parallel when available

Key variables you will see often:

- `PROVIDER`
- `NEWSPAPER`
- `NEWSPAPER_HAS_PROVIDER`
- `NEWSPAPERS_TO_PROCESS_FILE`
- `COLLECTION_JOBS`
- `NEWSPAPER_JOBS`
- `MAX_LOAD`
- `LOGGING_LEVEL`

## Pipelines Present

This repository contains reusable path/sync/setup/processing fragments for at least:

- `lingproc`
- `langident`
- `ocrqa`
- `topics`
- `bboxqa`
- `nel`
- `newsagencies`
- `consolidatedcanonical`
- `content_item_classification`
- `rebuilt` sampling flows

When changing a pipeline, inspect the matching family of files together:

- `paths_<name>.mk`
- `sync_<name>.mk`
- `setup_<name>.mk`
- `processing_<name>.mk`
- optionally `aggregators_<name>.mk`

## Safe Working Rules For Agents

- Do not commit or modify secrets in `.env` or `.aws/credentials`.
- Treat untracked local/sample files as user state unless clearly asked otherwise.
- Expect the worktree to contain local artifacts such as `.env`, sample JSONL files, or large compressed inputs.
- Avoid “clean up” changes that delete local data under `build.d/`, `.aws/`, or untracked sample files unless explicitly requested.
- Preserve the stamp-file semantics and the current S3 path conventions.
- When editing Make logic, follow the repository’s documented style:
  - user variables are exposed with comments
  - generic targets are extended with double-colon rules
  - target/help comments are part of the repo’s documentation style

## Practical Validation

Useful low-risk checks:

- inspect `README.md`, the relevant `*.mk` fragments, and `lib/` helpers together
- validate Python syntax for changed Python files
- use GNU Make 4+ before assuming a Make failure is caused by your change

Be careful with full pipeline execution:

- many targets require live S3 credentials and network access
- some setup/install targets write local config files
- `make help` itself is not portable here if it invokes the system Make 3.81 on macOS

## Current Local Notes

At the time this file was created, the worktree already contained untracked local files including:

- `.env`
- sample JSONL / `.bz2` inputs
- additional `lib/` helper samples and docs

Assume those are intentional local artifacts, not repository garbage.
