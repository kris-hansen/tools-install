#Tools Install

## Overview

This is a script which intends to get a base Debian/Darwin box productive for multi language development with a single execution. It was originally inspired by [files.zate.org/code.sh](files.zate.org/code.sh)

I started working on this because I was running a virtual debian environment in a container and was frequently rebuilding it - so of course anything which can be repeated, can be scripted. Originally this script was a note which I kept stashed and pulled out periodically and then modified over time. I added it to GitHub hoping that it saves people some time and that others may help improve it. I use this now to ensure a consistent development 

## Scope
This script is highly opinionated as to what `productive` means and is focused on installing the following:

- VS Code Insiders
- Various VS Code extensions which I find useful
- Go (via GVM)
- Python (via Pyenv)
- Docker
- Flutter
- GCP SDK
- Node (via nvm)
- Various libraries and tools which I find useful

## Running the Script

This script is intended to run in a bash or zsh shell and can run by executing:

`bash install.sh`

(things will happen)

## Contributing

If you'd like to contribute to this project, please follow these steps:

1. Fork the repository on GitHub.
2. Clone your forked repository to your local machine.
3. Create a new branch for your changes.
4. Make your changes and commit them to your branch.
5. Push your branch to your forked repository on GitHub.
6. Open a pull request from your branch to the original repository.

I welcome all contributions, including bug fixes, new features, and documentation improvements but may not accept updates which are not part of my development environment. Thank you for your help in making this project better!