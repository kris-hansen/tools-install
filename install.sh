#!/bin/bash
# =============================================================================
# Development Environment Installer
# =============================================================================
# Sets up a complete development environment on macOS or Debian Linux.
# Run as a non-root user with sudo privileges.
#
# Usage: ./install.sh [--dry-run] [--verify] {all|homebrew|chrome|code|...}
#
# Flags:
#   --dry-run   Print what would be installed without installing anything
#   --verify    Check which tools are installed and report missing ones
# =============================================================================

set -euo pipefail

# --- Global Flags ------------------------------------------------------------

DRY_RUN=false
VERIFY_MODE=false
VERIFY_PASS=0
VERIFY_FAIL=0
VERIFY_WARN=0

# --- Logging & Helpers -------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_dry()     { echo -e "${BLUE}[DRY-RUN]${NC} Would: $1"; }

check_success() {
    if [ $? -eq 0 ]; then
        log_info "$1 successfully completed."
    else
        log_error "$1 failed. Exiting."
        exit 1
    fi
}

command_exists() {
    command -v "$1" &> /dev/null
}

app_exists() {
    [ -d "/Applications/$1.app" ]
}

# Wrapper: run brew install or log in dry-run mode
brew_install() {
    if $DRY_RUN; then
        log_dry "brew install $*"
    else
        brew install "$@" 2>/dev/null || log_warn "Failed to install: $*"
    fi
}

brew_cask_install() {
    if $DRY_RUN; then
        log_dry "brew install --cask $*"
    else
        brew install --cask "$@" 2>/dev/null || log_warn "Failed to install cask: $*"
    fi
}

# Verify helper: check if something is present
verify_command() {
    local name="$1"
    local cmd="$2"
    if command_exists "$cmd"; then
        echo -e "  ${GREEN}✓${NC} $name ($($cmd --version 2>/dev/null | head -1 || echo 'installed'))"
        ((VERIFY_PASS++)) || true
    else
        echo -e "  ${RED}✗${NC} $name (not found: $cmd)"
        ((VERIFY_FAIL++)) || true
    fi
}

verify_app() {
    local name="$1"
    if app_exists "$name"; then
        echo -e "  ${GREEN}✓${NC} $name.app"
        ((VERIFY_PASS++)) || true
    else
        echo -e "  ${RED}✗${NC} $name.app (not installed)"
        ((VERIFY_FAIL++)) || true
    fi
}

verify_dir() {
    local name="$1"
    local dir="$2"
    if [ -d "$dir" ]; then
        echo -e "  ${GREEN}✓${NC} $name ($dir)"
        ((VERIFY_PASS++)) || true
    else
        echo -e "  ${RED}✗${NC} $name ($dir not found)"
        ((VERIFY_FAIL++)) || true
    fi
}

# --- OS Detection ------------------------------------------------------------

what_am_i() {
    unset OS OSV CROS
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
    log_info "Detected OS: $OS ($(uname -m))"
}

# --- Package Manager ---------------------------------------------------------

get_homebrew() {
    if $VERIFY_MODE; then
        verify_command "Homebrew" "brew"
        return
    fi

    if command_exists brew; then
        log_info "Homebrew already installed, updating..."
        $DRY_RUN || brew update
        return
    fi

    if $DRY_RUN; then
        log_dry "Install Homebrew"
        return
    fi

    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [ "$OS" != "macOS" ]; then
        test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
        test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        test -r ~/.bash_profile && echo "eval \$($(brew --prefix)/bin/brew shellenv)" >> ~/.bash_profile
        echo "eval \$($(brew --prefix)/bin/brew shellenv)" >> ~/.profile
    fi
    check_success "Installation of Homebrew"
}

# --- Brew Taps ---------------------------------------------------------------

get_brew_taps() {
    local taps=(
        aws/tap
        encoredev/tap
        hashicorp/tap
        homebrew/services
        supabase/tap
    )

    if $VERIFY_MODE; then
        echo "  Brew taps:"
        for tap in "${taps[@]}"; do
            if brew tap 2>/dev/null | grep -q "^${tap}$"; then
                echo -e "    ${GREEN}✓${NC} $tap"
                ((VERIFY_PASS++)) || true
            else
                echo -e "    ${RED}✗${NC} $tap"
                ((VERIFY_FAIL++)) || true
            fi
        done
        return
    fi

    log_info "Adding brew taps..."
    for tap in "${taps[@]}"; do
        if $DRY_RUN; then
            log_dry "brew tap $tap"
        else
            brew tap "$tap" 2>/dev/null || log_warn "Tap $tap failed or already exists"
        fi
    done
}

# --- Browser -----------------------------------------------------------------

get_chrome() {
    if $VERIFY_MODE; then
        if [ "$OS" == "macOS" ]; then
            verify_app "Google Chrome"
        else
            verify_command "Google Chrome" "google-chrome-stable"
        fi
        return
    fi

    if [ "$OS" == "macOS" ]; then
        brew_cask_install google-chrome
    else
        if $DRY_RUN; then
            log_dry "Install Google Chrome via apt"
            return
        fi
        wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | $SUDO apt-key add -
        echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | $SUDO tee /etc/apt/sources.list.d/google-chrome.list
        $SUDO apt-get update && $SUDO apt-get install -y google-chrome-stable
        check_success "Installation of Google Chrome"
    fi
}

# --- Editors & IDEs ----------------------------------------------------------

get_code() {
    if $VERIFY_MODE; then
        verify_command "VS Code Insiders" "code-insiders"
        return
    fi

    log_info "Installing VS Code Insiders..."
    if [ "$OS" == "macOS" ]; then
        brew_cask_install visual-studio-code-insiders
    else
        if $DRY_RUN; then
            log_dry "Install VS Code Insiders via apt"
            return
        fi
        $SUDO apt-get install -y gpg
        curl -s https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
        $SUDO mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
        echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" | $SUDO tee /etc/apt/sources.list.d/vscode.list
        $SUDO apt-get update -y
        $SUDO apt-get install -y code-insiders libxss1 libasound2
        check_success "Installation of VS Code Insiders"
    fi
}

get_vscode_extensions() {
    local extensions=(
        # Core editing
        DavidAnson.vscode-markdownlint
        eamodio.gitlens
        ms-vscode.wordcount
        redhat.vscode-yaml
        yzhang.markdown-all-in-one
        michelemelluso.gitignore
        tomoki1207.pdf
        ms-vscode.live-server

        # AI assistants
        GitHub.copilot
        GitHub.copilot-chat
        anthropic.claude-code
        saoudrizwan.claude-dev
        openai.chatgpt
        openai.openai-chatgpt-adhoc

        # GitHub
        github.vscode-github-actions

        # Python
        ms-python.python
        ms-python.debugpy
        ms-python.vscode-pylance
        ms-python.vscode-python-envs

        # Go
        golang.go

        # Dart / Flutter
        dart-code.dart-code
        dart-code.flutter
        alexisvt.flutter-snippets

        # Lua
        jep-a.lua-plus
        sumneko.lua

        # Markdown / MDX
        unifiedjs.vscode-mdx
        xyc.vscode-mdx-preview

        # Containers & Cloud
        ms-azuretools.vscode-containers
        ms-azuretools.vscode-docker
        ms-kubernetes-tools.vscode-kubernetes-tools
        ms-vscode-remote.remote-containers

        # Jupyter
        ms-toolsai.jupyter
        ms-toolsai.jupyter-keymap
        ms-toolsai.jupyter-renderers
        ms-toolsai.vscode-jupyter-cell-tags
        ms-toolsai.vscode-jupyter-slideshow

        # Java/Gradle
        vscjava.vscode-gradle

        # Custom
        4utopiainc.beads-vscode
    )

    if $VERIFY_MODE; then
        local CODE_CMD=""
        command_exists code-insiders && CODE_CMD="code-insiders"
        command_exists code && CODE_CMD="code"
        if [ -z "$CODE_CMD" ]; then
            echo -e "  ${RED}✗${NC} VS Code not installed, cannot verify extensions"
            ((VERIFY_FAIL++)) || true
            return
        fi
        local installed
        installed=$($CODE_CMD --list-extensions 2>/dev/null)
        local missing=0
        for ext in "${extensions[@]}"; do
            if echo "$installed" | grep -qi "^${ext}$"; then
                ((VERIFY_PASS++)) || true
            else
                echo -e "  ${RED}✗${NC} Extension missing: $ext"
                ((VERIFY_FAIL++)) || true
                ((missing++)) || true
            fi
        done
        if [ "$missing" -eq 0 ]; then
            echo -e "  ${GREEN}✓${NC} All ${#extensions[@]} VS Code extensions installed"
        fi
        return
    fi

    local CODE_CMD=""
    command_exists code-insiders && CODE_CMD="code-insiders"
    command_exists code && CODE_CMD="code"
    if [ -z "$CODE_CMD" ]; then
        log_warn "No VS Code installation found, skipping extensions"
        return
    fi

    log_info "Installing ${#extensions[@]} VS Code extensions..."
    for extension in "${extensions[@]}"; do
        if $DRY_RUN; then
            log_dry "$CODE_CMD --install-extension $extension"
        else
            $CODE_CMD --install-extension "$extension" --force 2>/dev/null || log_warn "Failed to install $extension"
        fi
    done

    $DRY_RUN || $CODE_CMD --list-extensions --show-versions
}

# --- Languages ---------------------------------------------------------------

get_python() {
    if $VERIFY_MODE; then
        verify_command "pyenv" "pyenv"
        verify_command "Python" "python3"
        return
    fi

    log_info "Installing pyenv and Python..."
    if [ "$OS" == "macOS" ]; then
        brew_install pyenv pyenv-virtualenv
    else
        if $DRY_RUN; then
            log_dry "Install pyenv build dependencies via apt"
            log_dry "Install pyenv via curl"
        else
            $SUDO apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev \
                libreadline-dev libsqlite3-dev wget curl llvm libncursesw5-dev xz-utils \
                tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
            curl https://pyenv.run | bash
        fi
    fi

    if $DRY_RUN; then
        log_dry "Configure pyenv in shell rc"
        log_dry "pyenv install 3.12.0 && pyenv global 3.12.0"
        return
    fi

    local SHELL_RC="$HOME/.zshrc"
    [ "$OS" != "macOS" ] && SHELL_RC="$HOME/.bashrc"

    if ! grep -q 'pyenv init' "$SHELL_RC" 2>/dev/null; then
        echo 'export PYENV_ROOT="$HOME/.pyenv"' >> "$SHELL_RC"
        echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> "$SHELL_RC"
        echo 'eval "$(pyenv init --path)"' >> "$SHELL_RC"
        echo 'eval "$(pyenv virtualenv-init -)"' >> "$SHELL_RC"
    fi

    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)" 2>/dev/null || true

    local PYTHON_VERSION="3.12.0"
    pyenv install -s "$PYTHON_VERSION"
    pyenv global "$PYTHON_VERSION"
    check_success "Installation of Python $PYTHON_VERSION"
}

get_node() {
    if $VERIFY_MODE; then
        # nvm is a shell function, not a binary — check for its directory instead
        verify_dir "nvm" "$HOME/.nvm"
        verify_command "Node.js" "node"
        verify_command "npm" "npm"
        return
    fi

    log_info "Installing Node.js via NVM..."

    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        log_info "NVM already installed, loading..."
        export NVM_DIR="$HOME/.nvm"
        \. "$NVM_DIR/nvm.sh"
    else
        if $DRY_RUN; then
            log_dry "Install NVM via curl"
            log_dry "nvm install node"
            return
        fi
        latest_nvm=$(curl --silent "https://api.github.com/repos/nvm-sh/nvm/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${latest_nvm}/install.sh" | bash
        check_success "Installation of NVM"
        export NVM_DIR="$HOME/.nvm"
        \. "$NVM_DIR/nvm.sh"
    fi

    if $DRY_RUN; then
        log_dry "nvm install node && nvm use node"
        return
    fi

    nvm install node
    nvm use node
    check_success "Installation of latest Node.js"
    node -v
}

get_go() {
    if $VERIFY_MODE; then
        verify_command "Go" "go"
        return
    fi

    log_info "Installing Go..."
    if [ "$OS" == "macOS" ]; then
        brew_install go

        if ! $DRY_RUN; then
            local SHELL_RC="$HOME/.zshrc"
            if ! grep -q 'GOPATH' "$SHELL_RC" 2>/dev/null; then
                echo 'export GOPATH=$HOME/go' >> "$SHELL_RC"
                echo 'export PATH=$PATH:$GOPATH/bin' >> "$SHELL_RC"
            fi
        fi
    else
        if $DRY_RUN; then
            log_dry "Install Go via GVM"
            return
        fi
        bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
        echo '[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"' >> ~/.bashrc
        source ~/.bashrc
        latest=$(gvm listall | grep -o 'go[0-9]\+\.[0-9]\+\.[0-9]\+$' | sort -V | tail -1)
        gvm install "$latest"
        gvm use "$latest" --default
        check_success "Installation of Go"
    fi
}

get_flutter() {
    if $VERIFY_MODE; then
        verify_command "Flutter" "flutter"
        verify_dir "Flutter SDK" "$HOME/flutter"
        return
    fi

    log_info "Installing Flutter..."
    if $DRY_RUN; then
        log_dry "git clone flutter to ~/flutter"
        log_dry "flutter precache && flutter doctor"
        return
    fi

    if [ -d "$HOME/flutter" ]; then
        log_info "Flutter directory exists, updating..."
        (cd "$HOME/flutter" && git pull)
    else
        git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
    fi

    local SHELL_RC="$HOME/.zshrc"
    [ "$OS" != "macOS" ] && SHELL_RC="$HOME/.bashrc"
    if ! grep -q 'flutter/bin' "$SHELL_RC" 2>/dev/null; then
        echo 'export PATH="$PATH:$HOME/flutter/bin"' >> "$SHELL_RC"
    fi

    export PATH="$PATH:$HOME/flutter/bin"
    flutter precache
    flutter doctor
    check_success "Installation of Flutter"
}

get_ruby() {
    if $VERIFY_MODE; then
        verify_command "rbenv" "rbenv"
        return
    fi

    log_info "Installing Ruby via rbenv..."
    if [ "$OS" == "macOS" ]; then
        brew_install rbenv ruby-build

        if ! $DRY_RUN; then
            local SHELL_RC="$HOME/.zshrc"
            if ! grep -q 'rbenv init' "$SHELL_RC" 2>/dev/null; then
                echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> "$SHELL_RC"
                echo 'eval "$(rbenv init -)"' >> "$SHELL_RC"
            fi
        fi
    fi
}

get_deno() {
    if $VERIFY_MODE; then
        verify_command "Deno" "deno"
        return
    fi

    log_info "Installing Deno..."
    brew_install deno
}

# --- Docker ------------------------------------------------------------------

get_docker() {
    if $VERIFY_MODE; then
        # On macOS, Docker Desktop provides the docker CLI — check for the app
        if [ "$OS" == "macOS" ]; then
            if app_exists "Docker" || app_exists "Docker Desktop"; then
                echo -e "  ${GREEN}✓${NC} Docker Desktop"
                ((VERIFY_PASS++)) || true
            else
                echo -e "  ${RED}✗${NC} Docker Desktop (not installed)"
                ((VERIFY_FAIL++)) || true
            fi
        else
            verify_command "Docker" "docker"
        fi
        verify_command "Docker Compose" "docker-compose"
        return
    fi

    log_info "Installing Docker..."
    if [ "$OS" == "macOS" ]; then
        brew_cask_install docker
        brew_install docker-compose
    else
        if $DRY_RUN; then
            log_dry "Install Docker via apt"
            return
        fi
        $SUDO apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
        curl -fsSL https://download.docker.com/linux/debian/gpg | $SUDO apt-key add -
        echo "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | $SUDO tee /etc/apt/sources.list.d/docker.list
        $SUDO apt-get update
        $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io
        $SUDO usermod -aG docker $(whoami)
        check_success "Installation of Docker"
    fi
}

# --- AI Tools ----------------------------------------------------------------

get_ai_tools() {
    if $VERIFY_MODE; then
        echo ""
        echo "AI Tools — CLI:"
        verify_command "Claude Code CLI" "claude"
        verify_command "Ollama" "ollama"
        verify_command "Codex" "codex"
        verify_command "Gemini CLI" "gemini"
        # copilot-cli binary may be 'github-copilot-cli' or 'ghcp'
        if command_exists github-copilot-cli || command_exists ghcp; then
            echo -e "  ${GREEN}✓${NC} Copilot CLI"
            ((VERIFY_PASS++)) || true
        else
            echo -e "  ${YELLOW}?${NC} Copilot CLI (not found — may not be available via brew)"
            ((VERIFY_WARN++)) || true
        fi
        echo ""
        echo "AI Tools — Desktop Apps:"
        verify_app "Claude"
        verify_app "ChatGPT"
        verify_app "LM Studio"
        verify_app "Perplexity"
        return
    fi

    log_info "Installing AI development tools..."

    # Desktop apps (all via brew cask)
    if [ "$OS" == "macOS" ]; then
        brew_cask_install claude
        brew_cask_install chatgpt
        brew_cask_install lm-studio
        # Perplexity is not available as a cask — App Store only
        if ! app_exists "Perplexity"; then
            log_warn "Perplexity: Install from App Store or https://perplexity.ai/download"
        fi
    fi

    # Claude Code CLI (via npm — needs node installed first)
    if command_exists npm; then
        if $DRY_RUN; then
            log_dry "npm install -g @anthropic-ai/claude-code"
        else
            npm install -g @anthropic-ai/claude-code 2>/dev/null || log_warn "Claude Code CLI install failed — may need manual install"
        fi
    else
        log_warn "npm not found — install Node.js first, then run: npm install -g @anthropic-ai/claude-code"
    fi

    # CLI AI tools via brew
    brew_install ollama
    brew_install codex
    brew_install gemini-cli
    brew_install copilot-cli
}

# --- Cloud & Infrastructure Tools -------------------------------------------

get_cloud_tools() {
    if $VERIFY_MODE; then
        echo ""
        echo "Cloud & Infrastructure:"
        verify_command "AWS CLI" "aws"
        verify_command "Terraform" "terraform"
        verify_command "Terragrunt" "terragrunt"
        verify_command "Supabase CLI" "supabase"
        verify_command "Temporal CLI" "temporal"
        verify_dir "Google Cloud SDK" "$HOME/google-cloud-sdk"
        return
    fi

    log_info "Installing cloud and infrastructure tools..."

    brew_install awscli
    brew_install terraform
    brew_install terragrunt
    brew_install supabase/tap/supabase
    brew_install temporal

    # Google Cloud SDK
    if [ ! -d "$HOME/google-cloud-sdk" ]; then
        if $DRY_RUN; then
            log_dry "Install Google Cloud SDK via curl"
        else
            log_info "Installing Google Cloud SDK..."
            curl https://sdk.cloud.google.com | bash -s -- --disable-prompts
            log_info "Run 'gcloud init' after installation to configure"
        fi
    else
        log_info "Google Cloud SDK already installed"
    fi
}

# --- Terminal & Shell Tools --------------------------------------------------

get_terminal_tools() {
    if $VERIFY_MODE; then
        echo ""
        echo "Terminal & Shell:"
        verify_command "tmux" "tmux"
        verify_dir "TPM" "$HOME/.tmux/plugins/tpm"
        if [ "$OS" == "macOS" ]; then
            verify_app "Ghostty"
        fi
        return
    fi

    log_info "Installing terminal tools..."

    if [ "$OS" == "macOS" ]; then
        brew_cask_install ghostty
    fi

    brew_install tmux

    # Set up TPM (Tmux Plugin Manager)
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        if $DRY_RUN; then
            log_dry "git clone TPM to ~/.tmux/plugins/tpm"
        else
            log_info "Installing TPM (Tmux Plugin Manager)..."
            git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
        fi
    fi
}

# --- macOS Desktop Apps ------------------------------------------------------

get_mac_apps() {
    if [ "$OS" != "macOS" ]; then
        log_warn "mac-apps is only available on macOS"
        return
    fi

    if $VERIFY_MODE; then
        echo ""
        echo "macOS Desktop Apps:"
        verify_app "Arc"
        verify_app "Bitwarden"
        verify_app "Discord"
        verify_app "Ghostty"
        verify_app "Raycast"
        verify_app "Signal"
        verify_app "Slack"
        verify_app "superwhisper"
        verify_app "zoom.us"
        verify_app "Xcode"
        return
    fi

    log_info "Installing macOS desktop apps via brew cask..."

    local casks=(
        arc
        bitwarden
        discord
        raycast
        signal
        slack
        superwhisper
        zoom
    )

    for cask in "${casks[@]}"; do
        brew_cask_install "$cask"
    done

    # Xcode is App Store only
    if ! app_exists "Xcode"; then
        log_warn "Xcode: Install from the App Store (then run: xcode-select --install)"
    fi
}

# --- Misc Mac Tools ----------------------------------------------------------

misc_mac_tools() {
    if [ "$OS" != "macOS" ]; then
        log_warn "misc_mac_tools is only available on macOS"
        return
    fi

    local formulae=(
        bat
        coreutils
        ffmpeg
        gh
        ghostscript
        glow
        gnupg
        htop
        imagemagick
        jq
        libpq
        nmap
        pipx
        redis
        ripgrep
        speedtest-cli
        tesseract
        tree
        wget
        yarn
        yq
        yt-dlp
    )

    local casks=(
        bruno
        dbeaver-community
        ngrok
        rectangle
        spotify
    )

    # Map brew formula names to their actual binary names
    verify_formula() {
        local formula="$1"
        case "$formula" in
            coreutils)    verify_command "$formula" "gls" ;;
            ghostscript)  verify_command "$formula" "gs" ;;
            gnupg)        verify_command "$formula" "gpg" ;;
            imagemagick)  verify_command "$formula" "magick" ;;
            libpq)        verify_command "$formula (psql)" "psql" ;;
            redis)        verify_command "$formula" "redis-cli" ;;
            ripgrep)      verify_command "$formula" "rg" ;;
            *)            verify_command "$formula" "$formula" ;;
        esac
    }

    if $VERIFY_MODE; then
        echo ""
        echo "CLI Tools:"
        for formula in "${formulae[@]}"; do
            verify_formula "$formula"
        done
        echo ""
        echo "GUI Tools:"
        for cask in "${casks[@]}"; do
            # Cask names don't always match app names, check common mappings
            case "$cask" in
                dbeaver-community) verify_app "DBeaver" ;;
                bruno)             verify_app "Bruno" ;;
                ngrok)             verify_command "ngrok" "ngrok" ;;
                rectangle)         verify_app "Rectangle" ;;
                spotify)           verify_app "Spotify" ;;
                *)                 verify_command "$cask" "$cask" ;;
            esac
        done
        return
    fi

    log_info "Installing miscellaneous macOS tools..."

    for formula in "${formulae[@]}"; do
        brew_install "$formula"
    done

    for cask in "${casks[@]}"; do
        brew_cask_install "$cask"
    done
}

# --- VS Code Settings Export/Import ------------------------------------------

export_vscode_settings() {
    log_info "Exporting VS Code settings..."
    local SETTINGS_DIR="$(dirname "$0")/vscode-settings"
    mkdir -p "$SETTINGS_DIR"

    local CODE_CMD=""
    if command_exists code-insiders; then
        CODE_CMD="code-insiders"
        cp "$HOME/Library/Application Support/Code - Insiders/User/settings.json" "$SETTINGS_DIR/" 2>/dev/null
        cp "$HOME/Library/Application Support/Code - Insiders/User/keybindings.json" "$SETTINGS_DIR/" 2>/dev/null
    elif command_exists code; then
        CODE_CMD="code"
        cp "$HOME/Library/Application Support/Code/User/settings.json" "$SETTINGS_DIR/" 2>/dev/null
        cp "$HOME/Library/Application Support/Code/User/keybindings.json" "$SETTINGS_DIR/" 2>/dev/null
    fi

    if [ -n "$CODE_CMD" ]; then
        $CODE_CMD --list-extensions > "$SETTINGS_DIR/extensions.txt"
        log_info "VS Code settings exported to $SETTINGS_DIR/"
        log_info "Exported $(wc -l < "$SETTINGS_DIR/extensions.txt" | tr -d ' ') extensions"
    fi
}

import_vscode_settings() {
    log_info "Importing VS Code settings..."
    local SETTINGS_DIR="$(dirname "$0")/vscode-settings"

    if [ ! -d "$SETTINGS_DIR" ]; then
        log_warn "No exported VS Code settings found at $SETTINGS_DIR"
        return
    fi

    local CODE_CMD=""
    local USER_SETTINGS_DIR=""
    if command_exists code-insiders; then
        CODE_CMD="code-insiders"
        USER_SETTINGS_DIR="$HOME/Library/Application Support/Code - Insiders/User"
    elif command_exists code; then
        CODE_CMD="code"
        USER_SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
    fi

    if [ -n "$CODE_CMD" ] && [ -n "$USER_SETTINGS_DIR" ]; then
        if $DRY_RUN; then
            log_dry "Copy settings.json and keybindings.json to $USER_SETTINGS_DIR"
            log_dry "Install extensions from extensions.txt"
            return
        fi

        mkdir -p "$USER_SETTINGS_DIR"
        [ -f "$SETTINGS_DIR/settings.json" ] && cp "$SETTINGS_DIR/settings.json" "$USER_SETTINGS_DIR/"
        [ -f "$SETTINGS_DIR/keybindings.json" ] && cp "$SETTINGS_DIR/keybindings.json" "$USER_SETTINGS_DIR/"

        if [ -f "$SETTINGS_DIR/extensions.txt" ]; then
            local total
            total=$(wc -l < "$SETTINGS_DIR/extensions.txt" | tr -d ' ')
            local count=0
            while IFS= read -r ext; do
                ((count++)) || true
                echo -ne "\r  Installing extension $count/$total: $ext"
                $CODE_CMD --install-extension "$ext" --force 2>/dev/null
            done < "$SETTINGS_DIR/extensions.txt"
            echo ""
        fi

        log_info "VS Code settings imported successfully"
    fi
}

# --- Config Setup ------------------------------------------------------------

setup_ghostty_config() {
    if $VERIFY_MODE; then
        if [ -f "$HOME/.config/ghostty/config" ]; then
            echo -e "  ${GREEN}✓${NC} Ghostty config"
            ((VERIFY_PASS++)) || true
        else
            echo -e "  ${RED}✗${NC} Ghostty config (~/.config/ghostty/config not found)"
            ((VERIFY_FAIL++)) || true
        fi
        return
    fi

    log_info "Setting up Ghostty config..."
    local GHOSTTY_DIR="$HOME/.config/ghostty"

    if $DRY_RUN; then
        log_dry "Create $GHOSTTY_DIR/config"
        return
    fi

    mkdir -p "$GHOSTTY_DIR"

    if [ ! -f "$GHOSTTY_DIR/config" ]; then
        cat > "$GHOSTTY_DIR/config" << 'GHOSTTY_EOF'
font-family = JetBrains Mono
window-width = 122
window-height = 32
GHOSTTY_EOF
        log_info "Ghostty config created"
    else
        log_info "Ghostty config already exists, skipping"
    fi
}

setup_claude_code() {
    if $VERIFY_MODE; then
        if [ -f "$HOME/.claude/settings.json" ]; then
            echo -e "  ${GREEN}✓${NC} Claude Code config"
            ((VERIFY_PASS++)) || true
        else
            echo -e "  ${RED}✗${NC} Claude Code config (~/.claude/settings.json not found)"
            ((VERIFY_FAIL++)) || true
        fi
        return
    fi

    log_info "Setting up Claude Code config..."
    local CLAUDE_DIR="$HOME/.claude"

    if $DRY_RUN; then
        log_dry "Create $CLAUDE_DIR/settings.json"
        return
    fi

    mkdir -p "$CLAUDE_DIR"

    if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
        cat > "$CLAUDE_DIR/settings.json" << 'CLAUDE_EOF'
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bd prime"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bd prime"
          }
        ]
      }
    ]
  },
  "enabledPlugins": {
    "gopls-lsp@claude-plugins-official": true
  }
}
CLAUDE_EOF
        log_info "Claude Code settings created"
    else
        log_info "Claude Code settings already exist, skipping"
    fi
}

# --- Main --------------------------------------------------------------------

run_all() {
    get_homebrew
    if [ "$OS" == "macOS" ]; then
        get_brew_taps
    fi
    get_chrome
    get_code
    get_vscode_extensions
    get_python
    get_go
    get_flutter
    get_ruby
    get_deno
    get_docker
    get_node
    get_ai_tools
    get_cloud_tools
    get_terminal_tools
    if [ "$OS" == "macOS" ]; then
        get_mac_apps
    fi
    misc_mac_tools
    setup_ghostty_config
    setup_claude_code
}

show_usage() {
    echo "Usage: $0 [--dry-run] [--verify] {all|homebrew|chrome|code|vscode-extensions|python|go|flutter|ruby|deno|docker|node|ai-tools|cloud-tools|terminal-tools|mac-apps|misc_mac_tools|export-vscode|import-vscode|ghostty|claude-code}..."
    echo ""
    echo "Flags:"
    echo "  --dry-run   Print what would be installed without actually installing"
    echo "  --verify    Check what is and isn't currently installed"
}

main() {
    what_am_i

    if ! command_exists curl; then
        log_error "curl is required but not installed. Exiting."
        exit 1
    fi

    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Exiting."
        exit 1
    fi

    SUDO="sudo -n"

    if $VERIFY_MODE; then
        echo ""
        echo "========================================="
        echo "  Environment Verification Report"
        echo "========================================="
        echo ""
    fi

    for arg in "$@"; do
        case "$arg" in
            all)               run_all ;;
            homebrew)          get_homebrew ;;
            chrome)            get_chrome ;;
            code)              get_code ;;
            vscode-extensions) get_vscode_extensions ;;
            python)            get_python ;;
            go)                get_go ;;
            flutter)           get_flutter ;;
            ruby)              get_ruby ;;
            deno)              get_deno ;;
            docker)            get_docker ;;
            node)              get_node ;;
            ai-tools)          get_ai_tools ;;
            cloud-tools)       get_cloud_tools ;;
            terminal-tools)    get_terminal_tools ;;
            mac-apps)          get_mac_apps ;;
            misc_mac_tools)    misc_mac_tools ;;
            export-vscode)     export_vscode_settings ;;
            import-vscode)     import_vscode_settings ;;
            ghostty)           setup_ghostty_config ;;
            claude-code)       setup_claude_code ;;
            *)
                log_error "Invalid argument: $arg"
                show_usage
                exit 1
                ;;
        esac
    done

    if $VERIFY_MODE; then
        echo ""
        echo "========================================="
        echo -e "  ${GREEN}Passed: $VERIFY_PASS${NC}  ${RED}Failed: $VERIFY_FAIL${NC}"
        echo "========================================="
        echo ""
        if [ "$VERIFY_FAIL" -gt 0 ]; then
            log_warn "Some tools are missing. Run './install.sh all' to install everything."
            exit 1
        else
            log_info "All checks passed!"
        fi
    fi
}

# Parse flags and arguments
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verify)
            VERIFY_MODE=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

if [ ${#ARGS[@]} -eq 0 ]; then
    echo "No arguments provided."
    show_usage
    exit 1
else
    main "${ARGS[@]}"
fi
