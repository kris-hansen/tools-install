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

# Function to check command success
check_success() {
    if [ $? -eq 0 ]; then
        echo "$1 successfully completed."
    else
        echo "$1 failed. Exiting."
        exit 1
    fi
}

# Main function to execute the installation logic based on command-line arguments
main() {
    # First check the runtime environment
    what_am_i
    # Initialize required commands list
    REQUIRED_COMMANDS="curl"

    # Append OS-specific required commands
    case "$OS" in
    Linux)
        REQUIRED_COMMANDS="$REQUIRED_COMMANDS gpg apt-get $SUDO"
        ;;
    Darwin|macOS)  # macOS is identified as "Darwin"
        REQUIRED_COMMANDS="$REQUIRED_COMMANDS"
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
    esac

    # Check for necessary commands
    for cmd in $REQUIRED_COMMANDS; do
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

    # Set sudo command with non-interactive flag to prevent asking for password again and again
    SUDO="sudo -n"

    for arg in "$@"; do
        case "$arg" in
            all)
                # Your existing code for installing all packages
                if [ "$OS" == "macOS" ]; then
                    # Install all macOS related packages
                    get_code_mac
                    get_python_mac
                    get_flutter_mac
                    get_go_mac
                    get_docker_mac
                    get_node
                else
                    # Install all Linux related packages
                    get_code
                    get_flutter
                    get_go
                    get_docker
                    get_python
                    get_node
                fi
                ;;
            code)
                if [ "$OS" == "macOS" ]; then
                    get_code_mac
                else
                    get_code
                fi
                ;;
            python)
                if [ "$OS" == "macOS" ]; then
                    get_python_mac
                else
                    get_python
                fi
                ;;
            flutter)
                if [ "$OS" == "macOS" ]; then
                    get_flutter_mac
                else
                    get_flutter
                fi
                ;;
            go)
                if [ "$OS" == "macOS" ]; then
                    get_go_mac
                else
                    get_go
                fi
                ;;
            docker)
                if [ "$OS" == "macOS" ]; then
                    get_docker_mac
                else
                    get_docker
                fi
                ;;
            node)
                get_node
                ;;
            *)
                echo "Invalid argument provided: $arg"
                echo "Usage: $0 {all|code|python|flutter|go|docker|node}..."
                exit 1
                ;;
        esac
    done
}

# Check if any command line argument is provided
if [ "$#" -eq 0 ]; then
    echo "No arguments provided."
    echo "Usage: $0 {all|code|python|flutter|go|docker|node}..."
    exit 1
else
    main "$@"
fi

