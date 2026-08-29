$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_python.mk)

###############################################################################
# PYTHON SETUP TARGETS
# Targets for setting up the Python environment including pip and pipenv
###############################################################################

# DOUBLE COLON TARGET specifications

setup:: setup-python-env

setup-python-env: setup-python setup-pip setup-pipenv check-venv-filesystem

help-setup::
	@echo "  setup-python-env # Set up the Python environment including pip and pipenv"

# USER-VARIABLE: PYTHON_MAJOR_VERSION
PYTHON_MINOR_VERSION ?= 11
  $(call log.debug, PYTHON_MINOR_VERSION)

PYTHON ?= $(if $(wildcard .venv/bin/python),.venv/bin/python,python3.$(PYTHON_MINOR_VERSION))
  $(call log.info, PYTHON)

# Export PYTHON so it's available in recursive make calls and subshells
export PYTHON


# TARGET: setup-python
#: Installs Python 3.$(PYTHON_MINOR_VERSION) based on the operating system
setup-python:
ifeq ($(OS),Linux)
	# Install Python 3.$(PYTHON_MINOR_VERSION) if not available
	if ! which python3.$(PYTHON_MINOR_VERSION) > /dev/null; then \
		sudo add-apt-repository ppa:deadsnakes/ppa && \
		sudo apt update && \
		sudo apt install -y python3.$(PYTHON_MINOR_VERSION) python3.$(PYTHON_MINOR_VERSION)-distutils ; \
	fi
else ifeq ($(OS),Darwin)
	# Install Python 3.$(PYTHON_MINOR_VERSION) if not available
	if ! which python3.$(PYTHON_MINOR_VERSION) > /dev/null; then \
		brew install python@3.$(PYTHON_MINOR_VERSION); \
	fi
endif

.PHONY: setup-python


# TARGET: setup-pip
#: Installs pip for the specified Python version if not available
setup-pip:
	# Install pip if not available
	if ! python3.$(PYTHON_MINOR_VERSION) -mpip help > /dev/null; then \
		curl -sS https://bootstrap.pypa.io/get-pip.py | python3.$(PYTHON_MINOR_VERSION); \
	fi

.PHONY: setup-pip

help-setup::
	@echo "  setup-python     # Install Python 3.$(PYTHON_MINOR_VERSION) if not available"
	@echo "  setup-pip        # Install pip for Python 3.$(PYTHON_MINOR_VERSION) if not available"


# TARGET: setup-pipenv
#: Installs pipenv for the specified Python version if not available
setup-pipenv:
	# Install pipenv if not available
	if ! python3.$(PYTHON_MINOR_VERSION) -mpipenv --version > /dev/null; then \
		python3.$(PYTHON_MINOR_VERSION) -mpip install pipenv ; \
	fi

.PHONY: setup-pipenv

help-setup::
	@echo "  setup-pipenv     # Install pipenv for Python 3.$(PYTHON_MINOR_VERSION) if not available"


# TARGET: check-venv-filesystem
#: Checks if virtual environment is on a network filesystem and warns about PyTorch issues
check-venv-filesystem:
ifeq ($(OS),Linux)
	@VENV_DIR="$(VENV_PATH)"; \
	if [ ! -d "$$VENV_DIR" ]; then \
		VENV_DIR="$$(dirname "$$VENV_DIR")"; \
	fi; \
	FS_TYPE=$$(df -T "$$VENV_DIR" 2>/dev/null | tail -1 | awk '{print $$2}'); \
	case "$$FS_TYPE" in \
		nfs|nfs4|cifs|smb|smbfs|fuse.sshfs) \
			echo ""; \
			echo "WARNING: Virtual environment path is on a network filesystem ($$FS_TYPE)"; \
			echo "         Path: $$VENV_DIR"; \
			echo ""; \
			echo "         PyTorch and other libraries with shared objects may fail with:"; \
			echo "         'OSError: failed to map segment from shared object'"; \
			echo ""; \
			echo "         RECOMMENDED SOLUTIONS:"; \
			echo "         1. Create venv on local disk:"; \
			echo "            python3.$(PYTHON_MINOR_VERSION) -m venv /tmp/.venv-impresso"; \
			echo "            /tmp/.venv-impresso/bin/pip install -r requirements.txt"; \
			echo "            gmake VENV_PATH=/tmp/.venv-impresso ..."; \
			echo ""; \
			echo "         2. Or add to .env or config.local.mk:"; \
			echo "            VENV_PATH = /tmp/.venv-impresso"; \
			echo ""; \
			echo "         3. Or use symlink:"; \
			echo "            mv $(VENV_PATH) /tmp/.venv-impresso"; \
			echo "            ln -s /tmp/.venv-impresso $(VENV_PATH)"; \
			echo ""; \
			;; \
	esac
endif

.PHONY: check-venv-filesystem

help-setup::
	@echo "  check-venv-filesystem # Check if venv is on network filesystem (Linux only)"


# TARGET: setup-pip-requirements
#: Updates pip package requirements.txt by pipenv
#
# We want requirements.txt to be more flexible for development.
# Pipfile.lock will contain the exact versions that the production system used.
setup-pip-requirements:
	pipenv lock
	pipenv requirements > requirements.txt

.PHONY: setup-pip-requirements

help-setup::
	@echo "  setup-pip-requirements # Update requirements.txt from pipenv lock data"

# TARGET: update-pip-requirements-file
#: Lock dependencies and regenerate requirements.txt using the project root Pipfile
#
# Overrides the cookbook/setup.mk version to always use --project-dir so the
# target works correctly regardless of the directory make is invoked from.
update-pip-requirements-file:
	pipenv --project-dir "$(CURDIR)" lock
	pipenv --project-dir "$(CURDIR)" requirements > "$(CURDIR)/requirements.txt"

.PHONY: update-pip-requirements-file

help-setup::
	@echo "  update-pip-requirements-file # Lock deps and regenerate requirements.txt"


# TARGET: clean-setup
#: Remove local Python setup/cache artifacts
clean-setup::
	# Removing Python bytecode caches...
	rm -rvf lib/__pycache__ || true

.PHONY: clean-setup

help-setup::
	@echo "  clean-setup     # Remove local Python setup/cache artifacts"

$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_python.mk)
