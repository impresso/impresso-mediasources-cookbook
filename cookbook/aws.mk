$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_aws.mk)
###############################################################################
# AWS SETUP TARGETS
# Targets for setting up and testing AWS credentials
#
# This Makefile snippet automates the process of setting up AWS CLI
# credentials and configuration from a `.env` file. It ensures that
# the required AWS configuration files are created with the correct
# values extracted from `.env`. This allows seamless authentication
# when using AWS CLI to interact with AWS services, such as S3.
#
# Prerequisites:
# - A properly configured `.env` file containing:
#   - `SE_HOST_URL`: AWS endpoint URL
#   - `SE_ACCESS_KEY`: AWS access key ID
#   - `SE_SECRET_KEY`: AWS secret access key
# - AWS CLI installed
#
# Functionality:
# - Creates the required AWS configuration files (.aws/config and .aws/credentials)
# - Reads credentials and settings from `.env`
# - Allows testing of AWS access by listing an S3 bucket
###############################################################################


# TARGET: test-aws
#: Tests AWS configuration by attempting to list S3 contents
#
# This target verifies if the AWS credentials and configuration are properly
# set up by listing the contents of an S3 bucket. Ensure that the required
# configuration files exist before running this command.
test-aws: .aws | .aws/credentials .aws/config
	AWS_CONFIG_FILE=.aws/config AWS_SHARED_CREDENTIALS_FILE=.aws/credentials \
	aws s3 ls s3://41-processed-data-staging/lingproc/lingproc-pos-spacy_v3.6.0-multilingual_v1-0-3/


# TARGET: create-aws-config
#: Creates AWS configuration files from environment variables
#
# This target ensures that the necessary AWS configuration and credentials files
# are generated from the environment variables defined in `.env`.
create-aws-config: .aws .aws/credentials .aws/config
	@echo ""
	@echo "AWS config files created."
	@echo "To add the required variables to your .env, paste and run:"
	@echo ""
	@echo "cat >> .env << 'EOF'"
	@echo "AWS_CONFIG_FILE=.aws/config"
	@echo "AWS_SHARED_CREDENTIALS_FILE=.aws/credentials"
	@echo "EOF"
	@echo ""

.aws:
	mkdir -p .aws
# TARGET: install-aws
#: Installs AWS CLI via pipenv
#
# This target installs the AWS CLI using `pipenv` to manage Python dependencies.
# Ensure that `pipenv` is installed before running this command.
install-aws:
	pipenv run pip install awscli


# FILE-RULE: .aws/config
#: Generates the AWS CLI configuration file from .env variables
#
# This rule reads values from the `.env` file and creates a local AWS configuration
# file under `.aws/config`. It ensures the directory exists before writing.
.aws/config: | .env
	@echo "Creating local AWS CLI configuration: $@"
	mkdir -p .aws
	@echo "[default]" > .aws/config
	@echo "region = us-east-1" >> .aws/config
	@echo "output = json" >> .aws/config
	@echo "endpoint_url = $$(grep SE_HOST_URL .env | cut -d '=' -f2)" >> .aws/config


# FILE-RULE: .aws/credentials
#: Generates the AWS CLI credentials file from .env variables
#
# This rule extracts AWS credentials from the `.env` file and writes them to
# `.aws/credentials`. Ensure that `.env` contains `SE_ACCESS_KEY` and `SE_SECRET_KEY`.
.aws/credentials: | .env
	@echo "Creating local AWS CLI credentials: $@"
	echo "[default]" > .aws/credentials
	@echo "aws_access_key_id = $$(grep SE_ACCESS_KEY .env | cut -d '=' -f2)" >> .aws/credentials
	@echo "aws_secret_access_key = $$(grep SE_SECRET_KEY .env | cut -d '=' -f2)" >> .aws/credentials


###############################################################################
# S3 CROSS-BUCKET FOLDER MOVE
#
# Moves (copies then deletes) a folder from one S3 bucket to another.
# There is no atomic rename across S3 buckets; `aws s3 mv --recursive` copies
# each object individually and then deletes the source objects.
#
# Always dry-run first to verify paths, then run the actual move.
#
# --- Direct AWS CLI commands (set credentials env vars first) ---
#
# Export credentials once:
#   export AWS_CONFIG_FILE=.aws/config
#   export AWS_SHARED_CREDENTIALS_FILE=.aws/credentials
#
# 1. Dry-run — lists all objects that would be moved, no data transferred:
#   aws s3 mv --recursive --dryrun \
#     s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS \
#     s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS
#
# 2. Actual move:
#   aws s3 mv --recursive \
#     s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS \
#     s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS
#
# To move an entire run across buckets (all providers):
#   aws s3 mv --recursive --dryrun \
#     s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/ \
#     s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/
#
# --- Make targets (see below) ---
#
#   make mv-s3-folder-dryrun \
#     S3_MV_SRC=s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS \
#     S3_MV_DST=s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS
#
#   make mv-s3-folder \
#     S3_MV_SRC=s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS \
#     S3_MV_DST=s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS
###############################################################################

S3_MV_SRC ?=
S3_MV_DST ?=

# TARGET: mv-s3-folder-dryrun
#: Dry-run of a cross-bucket S3 folder move — lists what would be copied/deleted
#
# Set S3_MV_SRC and S3_MV_DST on the command line. No data is transferred.
mv-s3-folder-dryrun:
	@test -n "$(S3_MV_SRC)" || (echo "ERROR: S3_MV_SRC is not set"; exit 1)
	@test -n "$(S3_MV_DST)" || (echo "ERROR: S3_MV_DST is not set"; exit 1)
	@echo "DRY RUN: $(S3_MV_SRC) -> $(S3_MV_DST)"
	AWS_CONFIG_FILE=.aws/config AWS_SHARED_CREDENTIALS_FILE=.aws/credentials \
	aws s3 mv --recursive --dryrun \
	  "$(S3_MV_SRC)" \
	  "$(S3_MV_DST)"

# TARGET: mv-s3-folder
#: Move a folder across S3 buckets (copy + delete source). Run dryrun first.
#
# Set S3_MV_SRC and S3_MV_DST on the command line.
# This copies all objects to the destination and then removes the source objects.
mv-s3-folder:
	@test -n "$(S3_MV_SRC)" || (echo "ERROR: S3_MV_SRC is not set"; exit 1)
	@test -n "$(S3_MV_DST)" || (echo "ERROR: S3_MV_DST is not set"; exit 1)
	@echo "MOVING: $(S3_MV_SRC) -> $(S3_MV_DST)"
	AWS_CONFIG_FILE=.aws/config AWS_SHARED_CREDENTIALS_FILE=.aws/credentials \
	aws s3 mv --recursive \
	  "$(S3_MV_SRC)" \
	  "$(S3_MV_DST)"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_aws.mk)

.PHONY: help-aws

help-aws::
	@echo ""
	@echo "AWS / S3 TARGETS:"
	@echo ""
	@echo "  INSTALLATION"
	@echo "    install-aws          # Install AWS CLI via pipenv"
	@echo ""
	@echo "  CONFIGURATION"
	@echo "    create-aws-config    # Generate .aws/config and .aws/credentials from .env"
	@echo "    Required .env variables:"
	@echo "      SE_HOST_URL        S3-compatible endpoint URL"
	@echo "      SE_ACCESS_KEY      AWS access key ID"
	@echo "      SE_SECRET_KEY      AWS secret access key"
	@echo ""
	@echo "  TESTING"
	@echo "    test-aws             # List S3 bucket contents to verify credentials"
	@echo ""
	@echo "  MOVING FOLDERS ACROSS BUCKETS"
	@echo "    Run dry-run first, then the actual move:"
	@echo ""
	@echo "    make mv-s3-folder-dryrun \\"
	@echo "      S3_MV_SRC=s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS \\"
	@echo "      S3_MV_DST=s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS"
	@echo ""
	@echo "    make mv-s3-folder \\"
	@echo "      S3_MV_SRC=s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS \\"
	@echo "      S3_MV_DST=s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS"
	@echo ""
	@echo "    Or directly with the AWS CLI (after exporting credentials):"
	@echo "      export AWS_CONFIG_FILE=.aws/config"
	@echo "      export AWS_SHARED_CREDENTIALS_FILE=.aws/credentials"
	@echo ""
	@echo "      # dry-run (single provider):"
	@echo "      aws s3 mv --recursive --dryrun \\"
	@echo "        s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS \\"
	@echo "        s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS"
	@echo ""
	@echo "      # dry-run (entire run, all providers):"
	@echo "      aws s3 mv --recursive --dryrun \\"
	@echo "        s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/ \\"
	@echo "        s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/"
	@echo ""
	@echo "      # actual move:"
	@echo "      aws s3 mv --recursive \\"
	@echo "        s3://114-canonical-processed-staging/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS \\"
	@echo "        s3://115-canonical-processed-final/langident/langident-lid-ensemble_multilingual_v2-0-2/RTS"
	@echo ""
