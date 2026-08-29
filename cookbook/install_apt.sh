sudo apt update
sudo apt upgrade -y
sudo apt install git git-lfs make remake parallel coreutils  # needed for building
# Ensure python3.11 and python3.11-dev are installed; add deadsnakes PPA only if python3.11 is not available in system repos
if ! dpkg -s python3.11 >/dev/null 2>&1 || ! dpkg -s python3.11-dev >/dev/null 2>&1; then
  # If the distro doesn't provide python3.11, add deadsnakes
  if apt-cache policy python3.11 | grep -q "Candidate: (none)"; then
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt update
  fi

  # Try to repair any partially-installed packages first
  sudo apt --fix-broken install -y || true

  # Install python3.11 and dev packages together to ensure consistent versions
  sudo apt install -y --allow-downgrades python3.11 python3.11-dev python3.11-distutils || true
fi
python3.11 -mpip help > /dev/null || { curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 ; }
