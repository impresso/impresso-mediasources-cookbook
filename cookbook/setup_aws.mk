$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_aws.mk)
###############################################################################
# AWS CONFIGURATION TARGETS
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
test-aws: | .aws/credentials .aws/config
	AWS_CONFIG_FILE=.aws/config AWS_SHARED_CREDENTIALS_FILE=.aws/credentials \
	aws s3 ls s3://41-processed-data-staging/lingproc/lingproc-pos-spacy_v3.6.0-multilingual_v1-0-3/

help-setup::
	@echo "  test-aws        # Test local AWS CLI config by listing an S3 prefix"


# TARGET: create-aws-config
#: Creates AWS configuration files from environment variables
#
# This target ensures that the necessary AWS configuration and credentials files
# are generated from the environment variables defined in `.env`.
create-aws-config: .aws/credentials .aws/config

help-setup::
	@echo "  create-aws-config # Create .aws/config and .aws/credentials from .env"


# TARGET: install-aws
#: Installs AWS CLI via pipenv
#
# This target installs the AWS CLI using `pipenv` to manage Python dependencies.
# Ensure that `pipenv` is installed before running this command.
install-aws:
	pipenv run pip install awscli

help-setup::
	@echo "  install-aws     # Install AWS CLI into the pipenv environment"


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
	mkdir -p .aws
	@echo "Creating local AWS CLI credentials: $@"
	echo "[default]" > .aws/credentials
	@echo "aws_access_key_id = $$(grep SE_ACCESS_KEY .env | cut -d '=' -f2)" >> .aws/credentials
	@echo "aws_secret_access_key = $$(grep SE_SECRET_KEY .env | cut -d '=' -f2)" >> .aws/credentials

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_aws.mk)
