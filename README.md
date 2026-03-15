# Tools Install

## Overview

This is a script which intends to get a base Debian/Darwin box productive for multi-language development with a single execution. It was originally inspired by [files.zate.org/code.sh](files.zate.org/code.sh)

I started working on this because I was running a virtual debian environment in a container and was frequently rebuilding it - so of course anything which can be repeated, can be scripted. Originally this script was a note which I kept stashed and pulled out periodically and then modified over time. I added it to GitHub hoping that it saves people some time and that others may help improve it. I use this now to ensure a consistent development environment when I get a new laptop or set up a new container for development.

## Scope

This script is highly opinionated as to what `productive` means and is focused on installing the following:

### Package Management
- Homebrew (Mac/Linux)
- Brew taps for AWS, Encore, HashiCorp, Supabase

### Languages & Runtimes
- Go (via brew on Mac, GVM on Linux)
- Python (via pyenv, default 3.12.0)
- Node.js (via nvm)
- Flutter/Dart
- Ruby (via rbenv)
- Deno

### Editors & Extensions
- VS Code Insiders with 37 extensions (AI, Python, Go, Dart, Lua, containers, etc.)
- VS Code settings export/import for migration

### AI Development Tools
- Claude Code CLI
- Claude Desktop, ChatGPT Desktop, LM Studio, Perplexity (manual download prompts)
- Ollama, Codex CLI, Gemini CLI, Copilot CLI

### Cloud & Infrastructure
- AWS CLI
- Google Cloud SDK
- Terraform & Terragrunt
- Supabase CLI
- Temporal CLI
- Docker & Docker Compose

### Terminal & Shell
- Ghostty (config setup)
- tmux + TPM (Tmux Plugin Manager)

### Miscellaneous Tools
- bat, ripgrep, jq, yq, gh, glow, htop, nmap, tree, wget
- ffmpeg, imagemagick, tesseract
- Bruno, DBeaver, ngrok, Rectangle, Spotify
- And more...

## Running the Script

```bash
./install.sh
Usage: ./install.sh {all|homebrew|chrome|code|vscode-extensions|python|go|flutter|
                     ruby|deno|docker|node|ai-tools|cloud-tools|terminal-tools|
                     misc_mac_tools|export-vscode|import-vscode|ghostty|claude-code}...
```

### Migration Workflow

When migrating to a new laptop, run on the **old** machine first:
```bash
./install.sh export-vscode
```

Then on the **new** machine:
```bash
./install.sh all
./install.sh import-vscode
```

## Contributing

If you'd like to contribute to this project, please follow these steps:

1. Fork the repository on GitHub.
2. Clone your forked repository to your local machine.
3. Create a new branch for your changes.
4. Make your changes and commit them to your branch.
5. Push your branch to your forked repository on GitHub.
6. Open a pull request from your branch to the original repository.

I welcome all contributions, including bug fixes, new features, and documentation improvements but may not accept updates which are not part of my development environment. Thank you for your help in making this project better!
