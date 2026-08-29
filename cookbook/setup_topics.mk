$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/setup_topics.mk)

###############################################################################
# SETUP TARGETS
# Targets for setting up the topic inference environment
###############################################################################


# TARGET: setup
# Prepares local directories and validates dependencies for topic inference
setup:: setup-topics


# TARGET: setup-topics
#: Sets up the topic inference environment
setup-topics: install-java check-python-installation newspaper-list-target | $(BUILD_DIR)
	mkdir -p $(LOCAL_PATH_TOPICS)

.PHONY: setup-topics

# USER-VARIABLE: JAVA_PACKAGE_APT
# Java package name to install on Debian/Ubuntu systems.
JAVA_PACKAGE_APT ?= openjdk-17-jre-headless

# USER-VARIABLE: JAVA_PACKAGE_BREW
# Java package name to install with Homebrew on macOS.
JAVA_PACKAGE_BREW ?= openjdk@17

# TARGET: install-java
#: Installs java
ifeq ($(OS),Linux)
install-java:
	which java >/dev/null || sudo apt-get install -y $(JAVA_PACKAGE_APT)

else ifeq ($(OS),Darwin)
install-java:
	which java >/dev/null || brew install $(JAVA_PACKAGE_BREW)
	echo "JAVA_HOME=$$(brew --prefix $(JAVA_PACKAGE_BREW))" > .env_java
	echo 'PATH=$$JAVA_HOME/bin:$$PATH' >> .env_java
endif

.PHONY: install-java

# TARGET: check-python-installation
#: Checks whether the Python environment is ready for Mallet topic inference
check-python-installation:
	$(if $(TOPICS_MALLET_HOME),MALLET_HOME=$(TOPICS_MALLET_HOME) ,)python3 lib/test_jpype_installation.py \
	  $(if $(TOPICS_DE_CONFIG),--config $(TOPICS_DE_CONFIG),) \
	  $(if $(TOPICS_FR_CONFIG),--config $(TOPICS_FR_CONFIG),) \
	  $(if $(TOPICS_EN_CONFIG),--config $(TOPICS_EN_CONFIG),) \
	  $(if $(TOPICS_LB_CONFIG),--config $(TOPICS_LB_CONFIG),) || \
	{ echo "Double check whether the required python packages are installed! or you running in the correct python environment!" ; exit 1; }

.PHONY: check-python-installation

help-setup::
	@echo "  setup-topics      # Set up Java, Python, and local paths for topic inference"
	@echo "  install-java      # Ensure a Java runtime is available for Mallet"
	@echo "  check-python-installation # Check whether the Python environment is set up correctly"


$(call log.debug, COOKBOOK END INCLUDE: cookbook/setup_topics.mk)
