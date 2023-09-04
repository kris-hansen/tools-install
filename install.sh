#!/bin/bash
# This script is intended to run on macOS or Debian-based Linux distributions
# It will install various development tools
# Please run this script as a non-root user who has sudo privileges

what_am_i() {
    # Clear any existing values
    unset OS
    unset OSV
    unset CROS
    # Check if the system is Linux or OSX
    if [ "$(uname -s)" == "Darwin" ]; then
        export OS="macOS"
    elif [ "$(uname -s)" == "Linux" ] && [ -x "$(command -v lsb_release)" ]; then
        export OS=$(lsb_release -is)
        export OSV=$(lsb_release -cs)
        if [ -d /mnt/chromeos ] && [ -d /dev/lxd ] && [ -f /opt/google/cros-containers/bin/garcon ]; then
            export CROS="yes"
        fi
    else
        echo "Unsupported OS"
        exit 1
    fi
}

get_code() {
    # This function installs Visual Studio Code and some extensions
    set -euf -o pipefail
    $SUDO apt-get install -y gpg
    check_success "Installation of GPG"

    curl -s https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    $SUDO mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" | $SUDO tee /etc/apt/sources.list.d/vscode.list
    check_success "Adding VS Code repository"

    $SUDO apt-get update -y
    $SUDO apt-get install -y code-insiders libxss1 libasound2
    check_success "Installation of VS Code"

    # Install the extensions
    extensions=(
      DavidAnson.vscode-markdownlint
      eamodio.gitlens
      ms-python.python
      golang.go
      ms-vscode.vscode-typescript-tslint-plugin
      ms-vscode.wordcount
      redhat.vscode-yaml
      yzhang.markdown-all-in-one
      GitHub.copilot
      GitHub.copilot-chat
    )

    for extension in "${extensions[@]}"; do
      code-insiders --install-extension $extension
    done

    code-insiders --list-extensions --show-versions
    check_success "Installation of VS Code extensions"
}

get_code_mac() {
  # This function installs Visual Studio Code and some extensions
  brew install --cask visual-studio-code-insiders
  # Install the extensions
  extensions=(
    DavidAnson.vscode-markdownlint
    eamodio.gitlens
    ms-python.python
    golang.go
    ms-vscode.vscode-typescript-tslint-plugin
    ms-vscode.wordcount
    redhat.vscode-yaml
    yzhang.markdown-all-in-one
    GitHub.copilot
    GitHub.copilot-chat
  )

  for extension in "${extensions[@]}"; do
    code-insiders --install-extension $extension
  done

  code-insiders --list-extensions --show-versions
}

get_docker() {
    # This function installs Docker
    $SUDO apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg2 \
        software-properties-common
    check_success "Installation of Docker dependencies"

    curl -fsSL https://download.docker.com/linux/debian/gpg | $SUDO apt-key add -
    echo "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | $SUDO tee /etc/apt/sources.list.d/docker.list
    check_success "Adding Docker repository"

    $SUDO apt-get update
    $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io
    check_success "Installation of Docker"

    $SUDO usermod -aG docker $(whoami)
}

get_docker_mac() {
  # This function installs Docker
  brew install --cask docker
}

get_node() {
    echo "Installing Node.js via NVM..."

    # Retrieve latest NVM version from Github API
    latest_nvm=$(curl --silent "https://api.github.com/repos/nvm-sh/nvm/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    # Download and install NVM
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${latest_nvm}/install.sh" | bash
    check_success "Installation of NVM"

    # Add the following lines to .bashrc or .bash_profile (on Mac) to source nvm
    echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> ~/.bashrc
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> ~/.bashrc

    # Source .bashrc to load new shell configs
    source ~/.bashrc

    # Install the latest version of Node.js
    nvm install node
    check_success "Installation of latest Node.js version"

    # Set the installed version as default
    nvm use node
    check_success "Setting latest Node.js version as default"

    echo "Installation of Node.js via NVM completed."
    echo "Version Information:"
    node -v
}


get_python() {
    # This function installs pyenv and Python-related build tools
    echo "Installing pyenv and Python build dependencies..."
    
    # Install dependencies for building Python
    $SUDO apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev wget curl llvm libncursesw5-dev xz-utils \
    tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
    check_success "Installation of Python build dependencies"
    
    # Install pyenv
    curl https://pyenv.run | bash
    check_success "Installation of pyenv"

    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(pyenv init --path)"' >> ~/.bashrc
    echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
    source ~/.bashrc
    check_success "Setting up pyenv"

    echo "Installation of pyenv and Python build tools completed."
}

get_python_mac() {
  # This function installs pyenv and Python-related build tools
  brew install pyenv pyenv-virtualenv
  echo 'eval "$(pyenv init --path)"' >> ~/.zshrc
  echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.zshrc
  source ~/.zshrc
}

get_flutter() {
    echo "Installing Flutter..."

    # Check if git is installed, if not, install it
    if ! command -v git &> /dev/null; then
        $SUDO apt-get install -y git
        check_success "Installation of Git"
    fi

    # Download and install Flutter SDK
    FLUTTER_CHANNEL=stable
    FLUTTER_VERSION=`curl -s https://storage.googleapis.com/flutter_infra/releases/releases_${FLUTTER_CHANNEL}.json | grep -o 'version[^"]*' | sort --version-sort | tail -1 | awk -F':' '{print $2}' | sed 's/\"//g' | tr -d '[:space:]'`

    cd ~
    git clone https://github.com/flutter/flutter.git -b $FLUTTER_VERSION
    check_success "Cloning Flutter repo"

    # Add Flutter to the path permanently
    echo 'export PATH="$PATH:`pwd`/flutter/bin"' >> ~/.bashrc
    source ~/.bashrc
    check_success "Adding Flutter to PATH"

    # Pre-download development binaries
    flutter precache
    check_success "Pre-downloading Flutter development binaries"

    # Check flutter installation
    flutter doctor
    echo "Installation of Flutter completed."
}

get_flutter_mac() {
  # This function installs Flutter
  git clone https://github.com/flutter/flutter.git -b stable ~/flutter
  echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
  source ~/.zshrc
  flutter precache
  flutter doctor
}

get_go() {
    echo "Installing Go via Go Version Manager (GVM)..."

    # Install GVM
    bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
    check_success "GVM installation"

    # Setup GVM
    echo "[[ -s \"\$HOME/.gvm/scripts/gvm\" ]] && source \"\$HOME/.gvm/scripts/gvm\"" >> ~/.bashrc
    source ~/.bashrc

    # Get latest Go version
    latest=$(gvm listall | grep -o 'go[0-9]\+\.[0-9]\+\.[0-9]\+$' | sort -V | tail -1)

    # Install the latest version of Go
    gvm install $latest
    check_success "Installation of latest Go version"

    gvm use $latest --default
    check_success "Setting latest Go version as default"

    echo "Installation of Go via GVM completed."
    echo "Version Information:"
    go version
}

get_go_mac() {
  # This function installs Go via Go Version Manager (GVM)
  brew install go
  echo 'export GOPATH=$HOME/go' >> ~/.zshrc
  echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.zshrc
  source ~/.zshrc
}


# Check for necessary commands
for cmd in $SUDO curl gpg apt-get; do
  if ! command -v $cmd &> /dev/null; then
    echo "This script requires $cmd, but it is not installed. Exiting."
    exit 1
  fi
done

# Check if the user is root
if [[ $EUID -eq 0 ]]; then
   echo "This script should not be run as root. Exiting."
   exit 1
fi

# Get OS and version info once at the start
if ! OS=$(lsb_release -is) || ! OSV=$(lsb_release -cs); then
    echo "Unsupported OS or unable to determine version."
    exit 1
fi

if [ "$OS" != "Debian" ] && [ "$OS" != "Ubuntu" ]; then
    echo "This script is designed for Debian-based distributions. You are running $OS."
    exit 1
fi

# Set sudo command with non-interactive flag to prevent asking for password again and again
SUDO="sudo -n"

# Function to check command success
check_success() {
    if [ $? -eq 0 ]; then
        echo "$1 successfully completed."
    else
        echo "$1 failed. Exiting."
        exit 1
    fi
}

# Main script
# First check the runtime environment
what_am_i

# Install necessary tools based on OS
if [ "$OS" == "macOS" ]; then
    # Install Homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    check_success "Installation of Homebrew"
    # Install Git
    brew install git
    check_success "Installation of Git"
    # Install Chrome
    brew install --cask google-chrome
    check_success "Installation of Google Chrome"
    # Install VS Code insiders
    get_code_mac
    # Install Python
    get_python_mac
    # Install Flutter
    get_flutter_mac
    # Install Go
    get_go_mac
    # Install Docker
    get_docker_mac
    # Install Node.js
    get_node
    brew install --cask tilix
    check_success "Installation of Tilix"
else
    # Ask for the sudo password upfront for Linux
    sudo -v
    # Keep sudo alive for the rest of the script for Linux
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    # Update and upgrade the system for Linux
    sudo apt-get update && sudo apt-get upgrade -y
    check_success "System update and upgrade"
    # Install VS Code insiders
    get_code
    # Install Flutter
    get_flutter
    # Install Go
    get_go
    # Install Docker
    get_docker
    # Install Python
    get_python
    # Install Node.js
    get_node
    # Setup Cloud SDK
    export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
    echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | $SUDO tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | $SUDO apt-key add -
    $SUDO apt-get update && $SUDO apt-get install -y google-cloud-sdk
    check_success "Installation of Google Cloud SDK"
    $SUDO apt install -y libglu1-mesa lib32stdc++6 python3-dev python3-pip python3-venv
    check_success "Installation of Python Build Dependencies"
    $SUDO pip3 install virtualenv wheel
    check_success "Installation of Python Build Tools"

    # Install Misc tools
    $SUDO apt-get install -y tilix xclip rlwrap
    check_success "Installation of Misc tools"
    curl https://cht.sh/:cht.sh | $SUDO tee /usr/local/bin/cht.sh
    $SUDO chmod +x /usr/local/bin/cht.sh
    check_success "Installation of cht.sh"
    echo "Package Installation completed"
fi

# List of go packages to install, both OS's
goPackages=(
  github.com/nsf/gocode
  github.com/uudashr/gopkgs/cmd/gopkgs
  github.com/ramya-rao-a/go-outline
  github.com/acroca/go-symbols
  golang.org/x/tools/cmd/guru
  golang.org/x/tools/cmd/gorename
  github.com/rogpeppe/godef
  github.com/sqs/goreturns
  golang.org/x/lint/golint
  github.com/derekparker/delve/cmd/dlv
)

for pkg in "${goPackages[@]}"; do
  go get "${pkg}"
  check_success "Installation of $pkg completed"
done
