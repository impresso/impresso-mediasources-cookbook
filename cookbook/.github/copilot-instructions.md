# GitHub Copilot Instructions for impresso-make-cookbook

## Project Overview

The **impresso-make-cookbook** is a Make-based build system for orchestrating complex NLP processing workflows on newspaper content. It provides a distributed, scalable processing pipeline that leverages AWS S3 for data storage and local stamp files for tracking progress across multiple machines.

## Core Technologies

- **Build System**: GNU Make (with `remake` for debugging)
- **Programming Language**: Python 3.11
- **Cloud Storage**: AWS S3 (via AWS CLI and boto3)
- **Key Tools**: 
  - GNU Parallel for parallelization
  - git-lfs for large file storage
  - jq for JSON processing
  - Java 17 for Mallet (topic modeling)
  - spaCy for NLP tasks

## Repository Structure

### Makefile Organization

The build system is modular, organized into specialized include files:

- **`log.mk`**: Logging utilities with configurable log levels (DEBUG, INFO, WARNING, ERROR)
- **`make_settings.mk`**: Core make settings and shell configuration
- **`setup*.mk`**: Setup targets for different processing environments
- **`paths_*.mk`**: Path definitions for different processing stages
- **`processing_*.mk`**: Processing targets for specific NLP tasks
- **`sync_*.mk`**: Data synchronization between S3 and local storage
- **`aggregators_*.mk`**: Data aggregation targets
- **`clean.mk`**: Cleanup targets for build artifacts

### Python Package (`lib/`)

A minimal Python package (`impresso_cookbook`) provides common utilities:
- S3 interaction helpers
- Path conversion utilities (`local_to_s3.py`)
- Data aggregation scripts
- Newspaper list management

## Coding Standards and Conventions

### Makefile Terminology

Use the project's specific terminology (as documented in README.md):

| Term | Definition | Use Case |
|------|------------|----------|
| **USER-VARIABLE** | User-configurable variable (`?=`) | Values users can override |
| **VARIABLE** | Internal computed variable (`:=`) | Internal calculations |
| **FUNCTION** | Transformation function (`define … endef`) | Reusable logic |
| **TARGET** | Target without recipe (`.PHONY`) | Dependency-only targets |
| **FILE-RULE** | Target with recipe creating a file | Actual file generation |
| **STAMPED-FILE-RULE** | Target creating a timestamp file | Progress tracking |
| **DOUBLE-COLON-TARGET** | Double-colon target without recipe (`::`) | Multiple independent dependencies |
| **DOUBLE-COLON-TARGET-RULE** | Double-colon target with recipe (`::`) | Independent execution rules |

### Variable Naming Conventions

- **User-configurable variables**: Use `?=` assignment (e.g., `PARALLEL_JOBS ?= $(NPROC)`)
- **Internal variables**: Use `:=` assignment for immediate expansion
- **Path variables**: End with `_DIR`, `_PATH`, or `_FILE` suffix
- **Option variables**: End with `_OPTION` suffix for command-line flags
- **S3 bucket variables**: Prefix with `S3_BUCKET_` (e.g., `S3_BUCKET_CANONICAL`)

### Logging Best Practices

Always use the logging functions instead of raw `echo`:

```make
$(call log.info,Processing newspaper: $(NEWSPAPER))
$(call log.debug,VARIABLE_NAME = $(VARIABLE_NAME))
$(call log.warning,Missing configuration file)
$(call log.error,Processing failed)
```

### Python Code Style

- Follow PEP 8 conventions
- Use type hints where appropriate
- Use `smart-open` for S3 file access
- Use `python-dotenv` for environment configuration
- Keep dependencies minimal (core: boto3, smart-open, jq)

## Build System Architecture

### Stamp File Pattern

The build system uses stamp files to track completion of processing tasks without storing full datasets locally:

1. **Local stamp files** mirror S3 metadata
2. **Targets depend on stamp files**, not actual data files
3. **Rules create stamp files** after successful S3 uploads
4. This enables distributed processing without conflicts

### S3 Integration

- **Input data**: Read from S3 buckets (canonical, rebuilt)
- **Output data**: Written to S3 buckets (processed stages)
- **Path conversion**: Use `LocalToS3` function to convert between local stamp paths and S3 paths
- **Validation**: Results validated before S3 upload (JSON schema, md5sum)

### Parallel Processing

The build system supports multiple levels of parallelization:

1. **Local parallelization**: Via Make's `-j` flag (auto-detected from CPU cores)
2. **Collection-level**: Multiple newspapers processed in parallel
3. **Newspaper-level**: Individual newspaper processing parallelized
4. **Distributed**: Multiple machines process independently using S3

Key variables:
- `NPROC`: Auto-detected CPU cores
- `PARALLEL_JOBS`: Max parallel jobs
- `COLLECTION_JOBS`: Parallel newspaper collections
- `NEWSPAPER_JOBS`: Jobs per newspaper
- `MAX_LOAD`: Maximum system load average

## Development Workflows

### Adding New Processing Stages

When adding a new processing stage (e.g., `newstage`):

1. Create `paths_newstage.mk` - Define input/output paths
2. Create `processing_newstage.mk` - Define processing targets and rules
3. Create `sync_newstage.mk` - Define S3 synchronization targets
4. Optionally create `setup_newstage.mk` - Environment setup
5. Include new files in main `Makefile`
6. Follow existing patterns for stamp files and S3 integration

### Testing Changes

1. **Test specific targets**: `make <target> NEWSPAPER=<test-newspaper>`
2. **Enable debug logging**: `make <target> LOGGING_LEVEL=DEBUG`
3. **Use dry-run mode**: `make <target> PROCESSING_S3_OUTPUT_DRY_RUN=--s3-output-dry-run`
4. **Test AWS connectivity**: `make test-aws`
5. **Validate parallel setup**: `make check-parallel`

### Common Make Targets

- `make help`: Show all available targets
- `make setup`: Initialize environment
- `make newspaper NEWSPAPER=<name>`: Process single newspaper
- `make collection`: Process multiple newspapers
- `make sync`: Sync data with S3
- `make clean-build`: Clean build artifacts

### Debugging

- **Use `remake`** for debugging: `remake -x --debugger`
- **Enable DEBUG logging**: `export LOGGING_LEVEL=DEBUG`
- **Check build rules**: `remake<0> info rules`
- **Disable pagers**: Always use `git --no-pager` in automation

## Environment Configuration

### Required Environment Variables

Create a `.env` file in the project root:

```bash
SE_ACCESS_KEY=your_access_key
SE_SECRET_KEY=your_secret_key
SE_HOST_URL=https://os.zhdk.cloud.switch.ch/
```

### Python Environment Setup

```bash
make setup-python-env  # Install Python 3.11, pip, pipenv
pipenv install         # Install dependencies
```

### AWS Configuration

```bash
make create-aws-config  # Generate AWS config from .env
make test-aws          # Test S3 connectivity
```

## Important Notes

### Do Not Modify
- **Existing working pipelines**: Only fix issues directly related to your changes
- **Unrelated tests**: Don't remove or edit unrelated tests
- **Build artifacts**: Use `.gitignore` for build outputs, stamps, and dependencies

### Path Management
- Always use **absolute paths** in Makefiles when referencing repository files
- Use **`LocalToS3` function** for path conversion between local stamps and S3 URIs
- Path variables should be **simply expanded** (`:=`) for consistency

### Stamp Files
- Stamp files use **`.d/` extension** (e.g., `build.d/stamps/`)
- Never commit stamp files to git (covered by `.gitignore`)
- Stamp files enable **stateless distributed processing**

### S3 Operations
- **Never overwrite** existing S3 results (unless explicitly intended)
- Always **validate** data before S3 upload
- Use **`PROCESSING_QUIT_IF_S3_OUTPUT_EXISTS_OPTION`** to skip existing outputs
- S3 operations should be **idempotent**

## Processing Pipelines

### Available Pipelines

1. **Language Identification** (`langident`): Multi-stage language classification
2. **Linguistic Processing** (`lingproc`): POS tagging, NER with spaCy
3. **OCR Quality Assessment** (`ocrqa`): OCR quality metrics
4. **Topic Modeling** (`topics`): Mallet-based topic modeling
5. **Bounding Box QA** (`bboxqa`): Bounding box quality assessment

Each pipeline follows the pattern:
- Input from S3 (canonical or rebuilt data)
- Local processing with stamp file tracking
- Output uploaded to S3
- Validation and integrity checks

## Contributing Guidelines

1. **Minimal changes**: Make the smallest possible modifications
2. **Test thoroughly**: Always test changes before committing
3. **Follow patterns**: Use existing code as templates
4. **Document changes**: Update relevant documentation
5. **Logging**: Add appropriate logging statements
6. **No secrets**: Never commit credentials or secrets

## Additional Resources

- Main documentation: `README.md`
- Makefile comments: Each `.mk` file has inline documentation
- Python package: `lib/pyproject.toml` and source files in `lib/`
- Example configurations: `*_TEMPLATE.mk` files
