# Update and upgrade Homebrew
brew update
brew upgrade

# Check if Python 3.11 is installed, install it if not
if ! which python3.11 > /dev/null; then
    brew install python@3.11
fi

# Ensure pip is installed for Python 3.11
if ! python3.11 -mpip help > /dev/null; then
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11
fi

# Install development tools needed for building
brew install git git-lfs make coreutils parallel
