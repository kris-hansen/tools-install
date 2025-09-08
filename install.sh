#!/bin/bash
# This script is intended to run on macOS or Debian-based Linux distributions
# It will install various development tools
# Please run this script as a non-root user who has sudo privileges

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
        echo -e "${RED}Unsupported OS${NC}"
        exit 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to check if a brew package is installed
brew_package_installed() {
    brew list --cask "$1" &> /dev/null || brew list "$1" &> /dev/null
}

get_homebrew() {
    if command_exists brew; then
        echo -e "${YELLOW}Homebrew is already installed. Updating...${NC}"
        brew update
        check_success "Homebrew update"
    else
        if [ "$OS" == "macOS" ]; then
            echo "Installing Homebrew for macOS..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            check_success "Installation of Homebrew"
        else
            echo "Installing Homebrew for Linux..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
            test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
            test -r ~/.bash_profile && echo "eval \$($(brew --prefix)/bin/brew shellenv)" >>~/.bash_profile
            echo "eval \$($(brew --prefix)/bin/brew shellenv)" >>~/.profile
            brew tap homebrew/cask-versions
            check_success "Installation of Homebrew"
            echo "Reloading shell so brew command can be found..."
            source ~/.profile
        fi
    fi
}

get_chrome() {
    # This function installs Google Chrome on Debian-based Linux systems
    if command_exists google-chrome-stable; then
        echo -e "${YELLOW}Google Chrome is already installed${NC}"
        return
    fi

    # Fetch and install the GPG key
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | $SUDO apt-key add -
    check_success "Adding Google's GPG key"

    # Add the Chrome repo to the sources list
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | $SUDO tee /etc/apt/sources.list.d/google-chrome.list
    check_success "Adding Google Chrome repository"

    # Update and install the stable version of Chrome
    $SUDO apt-get update
    $SUDO apt-get install -y google-chrome-stable
    check_success "Installation of Google Chrome"
}

get_chrome_mac() {
    # This function installs Google Chrome on macOS
    if brew_package_installed "google-chrome"; then
        echo -e "${YELLOW}Google Chrome is already installed${NC}"
        return
    fi

    # Use brew to install Chrome
    brew install --cask google-chrome
    check_success "Installation of Google Chrome on macOS"
}

get_rectangle_mac() {
    # This function installs Rectangle window manager on macOS
    if brew_package_installed "rectangle"; then
        echo -e "${YELLOW}Rectangle is already installed${NC}"
        return
    fi

    # Use brew to install Rectangle
    brew install --cask rectangle
    check_success "Installation of Rectangle window manager on macOS"
}

get_ollama_mac() {
    # This function installs Ollama on macOS
    if brew_package_installed "ollama"; then
        echo -e "${YELLOW}Ollama is already installed${NC}"
        return
    fi

    # Use brew to install Ollama
    brew install --cask ollama
    check_success "Installation of Ollama on macOS"
}

get_hyper_mac() {
    # This function installs Hyper terminal on macOS
    if brew_package_installed "hyper"; then
        echo -e "${YELLOW}Hyper is already installed${NC}"
        return
    fi

    # Use brew to install Hyper
    brew install --cask hyper
    check_success "Installation of Hyper terminal on macOS"
}

misc_mac_tools() {
    echo "Installing miscellaneous macOS tools..."
    local tools=(tree jq wget neofetch htop nmap speedtest-cli bat)
    
    for tool in "${tools[@]}"; do
        if brew_package_installed "$tool"; then
            echo -e "${YELLOW}$tool is already installed${NC}"
        else
            brew install "$tool"
            check_success "Installation of $tool"
        fi
    done
}

update_vscode_extensions() {
    # Function to install/update VS Code extensions
    local code_cmd="$1"
    
    echo "Installing/Updating VS Code extensions..."
    
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
        echo "Installing extension: $extension"
        $code_cmd --install-extension $extension --force
    done

    $code_cmd --list-extensions --show-versions
    check_success "Installation/Update of VS Code extensions"
}

get_code() {
    # This function installs Visual Studio Code and some extensions
    if command_exists code-insiders; then
        echo -e "${YELLOW}VS Code Insiders is already installed. Updating extensions...${NC}"
        update_vscode_extensions "code-insiders"
        return
    elif command_exists code; then
        echo -e "${YELLOW}VS Code is already installed. Updating extensions...${NC}"
        update_vscode_extensions "code"
        return
    fi

    set -euf -o pipefail
    $SUDO apt-get install -y gpg
    check_success "Installation of GPG"

    curl -s https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    $SUDO mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" | $SUDO tee /etc/apt/sources.list.d/vscode.list
    check_success "Adding VS Code repository"

    $SUDO apt-get update -y
    $SUDO apt-get install -y code libxss1 libasound2
    check_success "Installation of VS Code"

    update_vscode_extensions "code"
}

get_code_mac() {
    # This function installs Visual Studio Code and some extensions
    if command_exists code; then
        echo -e "${YELLOW}VS Code is already installed. Updating extensions...${NC}"
        update_vscode_extensions "code"
        return
    fi

    brew install --cask visual-studio-code
    check_success "Installation of VS Code"
    
    update_vscode_extensions "code"
}

get_docker() {
    # This function installs Docker
    if command_exists docker; then
        echo -e "${YELLOW}Docker is already installed${NC}"
        docker --version
        return
    fi

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
    echo -e "${YELLOW}Please log out and back in for Docker group changes to take effect${NC}"
}

get_docker_mac() {
    # This function installs Docker
    if brew_package_installed "docker"; then
        echo -e "${YELLOW}Docker is already installed${NC}"
        return
    fi

    brew install --cask docker
    check_success "Installation of Docker"
}

get_node() {
    echo "Installing/Updating Node.js via NVM..."

    # Check if NVM is already installed
    if [ -d "$HOME/.nvm" ]; then
        echo -e "${YELLOW}NVM is already installed. Updating...${NC}"
        cd "$HOME/.nvm"
        git fetch --tags origin
        git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)`
        \. "$HOME/.nvm/nvm.sh"
    else
        # Retrieve latest NVM version from Github API
        latest_nvm=$(curl --silent "https://api.github.com/repos/nvm-sh/nvm/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        # Download and install NVM
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${latest_nvm}/install.sh" | bash
        check_success "Installation of NVM"
    fi

    # Determine shell config file
    if [ "$OS" == "macOS" ]; then
        SHELL_CONFIG="$HOME/.zshrc"
    else
        SHELL_CONFIG="$HOME/.bashrc"
    fi

    # Add NVM to shell config if not already present
    if ! grep -q "NVM_DIR" "$SHELL_CONFIG"; then
        echo 'export NVM_DIR="$HOME/.nvm"' >> "$SHELL_CONFIG"
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> "$SHELL_CONFIG"
        echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> "$SHELL_CONFIG"
    fi

    # Source NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Install the latest LTS version of Node.js
    nvm install --lts
    nvm use --lts
    nvm alias default 'lts/*'
    check_success "Installation of latest LTS Node.js version"

    echo "Installation of Node.js via NVM completed."
    echo "Version Information:"
    node -v
    npm -v
}

get_python() {
    # This function installs pyenv, Python, and pip
    echo "Installing/Updating pyenv, Python, and pip..."
    
    # Install dependencies for building Python
    $SUDO apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev wget curl llvm libncursesw5-dev xz-utils \
    tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
    check_success "Installation of Python build dependencies"
    
    # Check if pyenv is already installed
    if [ -d "$HOME/.pyenv" ]; then
        echo -e "${YELLOW}pyenv is already installed. Updating...${NC}"
        cd "$HOME/.pyenv" && git pull
    else
        # Install pyenv
        curl https://pyenv.run | bash
        check_success "Installation of pyenv"
    fi

    # Add pyenv to shell config if not already present
    if ! grep -q "PYENV_ROOT" ~/.bashrc; then
        echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
        echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
        echo 'eval "$(pyenv init --path)"' >> ~/.bashrc
        echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
    fi
    
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    
    # Install latest stable Python 3
    LATEST_PYTHON=$(pyenv install --list | grep -E "^\s*3\.[0-9]+\.[0-9]+$" | tail -1 | xargs)
    pyenv install -s $LATEST_PYTHON
    pyenv global $LATEST_PYTHON
    check_success "Installation of Python $LATEST_PYTHON"

    echo "Installation of pyenv and Python completed."
    python --version
}

get_python_mac() {
    # This function installs pyenv, Python, and pip
    if command_exists pyenv; then
        echo -e "${YELLOW}pyenv is already installed. Updating...${NC}"
        brew upgrade pyenv pyenv-virtualenv
    else
        brew install pyenv pyenv-virtualenv
    fi
    
    # Add pyenv to shell config if not already present
    if ! grep -q "pyenv init" ~/.zshrc; then
        echo 'eval "$(pyenv init --path)"' >> ~/.zshrc
        echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.zshrc
    fi
    
    eval "$(pyenv init --path)"
    
    # Install latest stable Python 3
    LATEST_PYTHON=$(pyenv install --list | grep -E "^\s*3\.[0-9]+\.[0-9]+$" | tail -1 | xargs)
    pyenv install -s $LATEST_PYTHON
    pyenv global $LATEST_PYTHON
    check_success "Installation of Python $LATEST_PYTHON"
    
    python --version
}

get_flutter() {
    echo "Installing/Updating Flutter..."

    # Check if git is installed, if not, install it
    if ! command -v git &> /dev/null; then
        $SUDO apt-get install -y git
        check_success "Installation of Git"
    fi

    # Check if Flutter is already installed
    if [ -d "$HOME/flutter" ]; then
        echo -e "${YELLOW}Flutter is already installed. Updating...${NC}"
        cd "$HOME/flutter"
        git pull
        flutter upgrade
    else
        # Download and install Flutter SDK
        cd ~
        git clone https://github.com/flutter/flutter.git -b stable
        check_success "Cloning Flutter repo"
        
        # Add Flutter to the path permanently
        echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
    fi

    export PATH="$PATH:$HOME/flutter/bin"
    
    # Pre-download development binaries
    flutter precache
    check_success "Pre-downloading Flutter development binaries"

    # Check flutter installation
    flutter doctor
    echo "Installation of Flutter completed."
}

get_flutter_mac() {
    # This function installs Flutter
    if [ -d "$HOME/flutter" ]; then
        echo -e "${YELLOW}Flutter is already installed. Updating...${NC}"
        cd "$HOME/flutter"
        git pull
        flutter upgrade
    else
        git clone https://github.com/flutter/flutter.git -b stable ~/flutter
        echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
    fi
    
    export PATH="$PATH:$HOME/flutter/bin"
    flutter precache
    flutter doctor
}

get_go() {
    echo "Installing/Updating Go..."

    # Check if Go is already installed via package manager
    if command_exists go; then
        echo -e "${YELLOW}Go is already installed${NC}"
        go version
        return
    fi

    # Download and install latest Go
    LATEST_GO=$(curl -s https://go.dev/VERSION?m=text | head -1)
    wget "https://go.dev/dl/${LATEST_GO}.linux-amd64.tar.gz"
    $SUDO rm -rf /usr/local/go
    $SUDO tar -C /usr/local -xzf "${LATEST_GO}.linux-amd64.tar.gz"
    rm "${LATEST_GO}.linux-amd64.tar.gz"
    
    # Add Go to PATH
    if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        echo 'export GOPATH=$HOME/go' >> ~/.bashrc
        echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
    fi
    
    export PATH=$PATH:/usr/local/go/bin
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin
    
    check_success "Installation of Go"
    go version
}

get_go_mac() {
    # This function installs Go
    if command_exists go; then
        echo -e "${YELLOW}Go is already installed. Updating...${NC}"
        brew upgrade go
    else
        brew install go
    fi
    
    if ! grep -q "GOPATH" ~/.zshrc; then
        echo 'export GOPATH=$HOME/go' >> ~/.zshrc
        echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.zshrc
    fi
    
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin
    
    go version
}

get_gcloud_mac() {
    if brew_package_installed "google-cloud-sdk"; then
        echo -e "${YELLOW}Google Cloud SDK is already installed. Updating...${NC}"
        gcloud components update
    else
        brew install --cask google-cloud-sdk
        echo 'source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"' >> ~/.zshrc
        echo 'source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"' >> ~/.zshrc
    fi
}

# Function to check command success
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1 successfully completed.${NC}"
    else
        echo -e "${RED}✗ $1 failed. Exiting.${NC}"
        exit 1
    fi
}

# Function to print usage
print_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  all              Install all available tools for your OS"
    echo "  homebrew         Install/Update Homebrew package manager"
    echo "  chrome           Install Google Chrome"
    echo "  code             Install/Update VS Code and extensions"
    echo "  python           Install/Update Python via pyenv"
    echo "  flutter          Install/Update Flutter SDK"
    echo "  go               Install/Update Go programming language"
    echo "  docker           Install Docker"
    echo "  node             Install/Update Node.js via NVM"
    echo ""
    echo "macOS only:"
    echo "  gcloud           Install Google Cloud SDK"
    echo "  misc_mac_tools   Install misc command-line tools"
    echo "  rectangle        Install Rectangle window manager"
    echo "  ollama           Install Ollama"
    echo "  hyper            Install Hyper terminal"
    echo ""
    echo "You can specify multiple options at once."
}

# Main function to execute the installation logic based on command-line arguments
main() {
    # First check the runtime environment
    what_am_i
    
    echo -e "${GREEN}Detected OS: $OS${NC}"
    
    # Initialize required commands list
    REQUIRED_COMMANDS="curl"

    # Append OS-specific required commands
    case "$OS" in
    Linux|Ubuntu|Debian)
        REQUIRED_COMMANDS="$REQUIRED_COMMANDS apt-get"
        ;;
    Darwin|macOS)
        # macOS has everything needed by default
        ;;
    *)
        echo -e "${RED}Unsupported operating system: $OS${NC}"
        exit 1
        ;;
    esac

    # Check for necessary commands
    for cmd in $REQUIRED_COMMANDS; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}This script requires $cmd, but it is not installed. Exiting.${NC}"
            exit 1
        fi
    done

    # Check if the user is root
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}This script should not be run as root. Exiting.${NC}"
        exit 1
    fi

    # Set sudo command
    if [ "$OS" != "macOS" ]; then
        SUDO="sudo"
    fi

    for arg in "$@"; do
        case "$arg" in
            all)
                echo -e "${GREEN}Installing all packages for $OS...${NC}"
                if [ "$OS" == "macOS" ]; then
                    # Install all macOS related packages
                    get_homebrew
                    get_chrome_mac
                    get_code_mac
                    get_python_mac
                    get_flutter_mac
                    get_go_mac
                    get_docker_mac
                    get_node
                    misc_mac_tools
                    get_rectangle_mac
                    get_ollama_mac
                    get_hyper_mac
                    get_gcloud_mac
                else
                    # Install all Linux related packages
                    get_code
                    get_chrome
                    get_flutter
                    get_go
                    get_docker
                    get_python
                    get_node
                fi
                ;;
            homebrew)
                get_homebrew
                ;;
            chrome)
                if [ "$OS" == "macOS" ]; then
                    get_chrome_mac
                else
                    get_chrome
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
            gcloud)
                if [ "$OS" == "macOS" ]; then
                    get_gcloud_mac
                else
                    echo -e "${YELLOW}gcloud installation for Linux not yet implemented${NC}"
                fi
                ;;
            docker)
                if [ "$OS" == "macOS" ]; then
                    get_docker_mac
                else
                    get_docker
                fi
                ;;
            misc_mac_tools)
                if [ "$OS" == "macOS" ]; then
                    misc_mac_tools
                else
                    echo -e "${YELLOW}misc_mac_tools is only available on macOS${NC}"
                fi
                ;;
            rectangle)
                if [ "$OS" == "macOS" ]; then
                    get_rectangle_mac
                else
                    echo -e "${YELLOW}Rectangle is only available on macOS${NC}"
                fi
                ;;
            ollama)
                if [ "$OS" == "macOS" ]; then
                    get_ollama_mac
                else
                    echo -e "${YELLOW}Ollama is only available on macOS in this script${NC}"
                fi
                ;;
            hyper)
                if [ "$OS" == "macOS" ]; then
                    get_hyper_mac
                else
                    echo -e "${YELLOW}Hyper is only available on macOS in this script${NC}"
                fi
                ;;
            node)
                get_node
                ;;
            -h|--help|help)
                print_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid argument provided: $arg${NC}"
                print_usage
                exit 1
                ;;
        esac
    done

    echo -e "${GREEN}All requested installations completed!${NC}"
}

# Check if any command line argument is provided
if [ "$#" -eq 0 ]; then
    echo -e "${YELLOW}No arguments provided.${NC}"
    print_usage
    exit 1
else
    main "$@"
fi
