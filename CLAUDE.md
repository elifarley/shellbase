# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`shellbase` is a personal shell scripting environment and dotfiles repository. It provides shell functions, aliases, and configurations for bash, zsh, vim, git, Docker, Kubernetes, and terminal multiplexers (screen/tmux).

## Architecture

### File Organization

```
~/.bashrc          - Main bash configuration (sources .bashrc.d/*.sh)
~/.bash_profile    - Login shell (sources .bashrc, sets prompt)
~/.zshrc           - Zsh configuration
~/.bashrc.d/       - Modular bash configuration (loaded in numeric order)
├── 00-main.sh         - Core shell config (vi-mode, completion, history, prompt)
├── 05-env.sh          - Environment variables (EDITOR, LESS, colors, dircolors)
├── 10-aliases.sh      - Basic shell aliases (ls, grep, safety aliases)
├── 11-functions.sh    - Core utility functions (path_prepend, s, mvln, memstat)
├── 15-dev-tools.sh    - Development tools (Maven, Gradle, jq)
├── 16-git.sh          - Git functions (git.rename, git.grep, git.hlog)
├── 17-docker.sh       - Docker aliases/functions
├── 18-k8s.sh          - Kubernetes aliases/functions
├── 19-apps.sh         - App-specific aliases (kopia, ssh kitten, claude)
└── 20-local.sh        - Tool initialization (ssh-agent, python, nvm, hug)
~/.vimrc           - Vim configuration with Vundle plugin management
~/.gitconfig       - Git aliases and configuration (Hug-friendly)
~/.config/         - Application-specific configs (kitty, systemd)
installer/         - Installation scripts
```

### Configuration Sourcing Chain

1. **Bash login**: `~/.bash_profile` → `~/.bashrc` → `~/.bashrc.d/*.sh` (numeric order)
2. **Zsh**: `~/.zshrc` → sources `~/.shell-env` and `~/.shell-aliases` if present
3. **Hug SCM** is activated via: `~/IdeaProjects/hug-scm/bin/activate` (in 20-local.sh)

### Shell Options & Keybindings

- **Vi mode enabled**: `set -o vi` (bash) and `bindkey -v` (zsh)
- **Ctrl-R** history search enabled in vi mode
- **Ctrl-L** clears screen
- **Ctrl-S/Q** flow control disabled (`stty -ixon`)
- **Smart history**: 10,000 HISTSIZE, append mode, ignore duplicates

### Git Configuration

The `.gitconfig` file uses a comprehensive alias system designed to work with **Hug** (Humane Git). Key patterns:

- `hug` is aliased to `git`
- Aliases follow prefix conventions: `a*` (add), `b*` (branch), `c*` (commit), `l*` (log), etc.
- **Use `hug` command for all git operations** - not raw git
- Custom log formats: `hug l`, `hug ll`, `hug la` (all branches)
- Delta pager enabled for syntax-colored diffs

### Vim Configuration

- Uses **Vundle** for plugin management
- Key plugins: CtrlP, vim-fugitive, tagbar, supertab
- 256-color support with solarized theme
- Custom F-key mappings for common tasks (F2 paste toggle, F4 close buffer, etc.)

### Alias Categories

**Core utilities** (in `11-functions.sh`):
- `path_prepend()` - Safely add to PATH without duplicates
- `s` - sudo or sudo last command (`s` or `s command`)
- `mvln` - Move and symlink with relative paths
- `memstat` - Memory statistics including zram/zswap
- `cd_func` / `cd` - Directory history with pushd/popd

**Git** (in `16-git.sh`):
- `g` → `hug`
- `git.rename` - Rename branch locally and remotely
- `git.grep` - Search git history with log
- `git.hlog` - Human-readable log format with timestamps

**Maven/Gradle** (in `15-dev-tools.sh`):
- `mvnprop <property>` - Print Maven property value
- `mvndep [dependency]` - Show dependency tree
- `gradle.dep [dependency]` - Gradle dependency insight

**Docker** (in `17-docker.sh`):
- `drun <image> [cmd]` - Run container with shell
- `docker-rm-unused` - Remove exited containers
- `dimg`, `dstatus` - Inspection helpers

**Kubernetes** (in `18-k8s.sh`):
- `k` → `kubectl` (with namespace support via `KUBE_NAMESPACE`)
- `k.ns` - Set/get namespace
- `k.ctx` - Set/get context
- `k.get-secrets <deployment>` - Decode deployment secrets
- `k.list-pods-in-deployment <deployment>` - List pods for deployment

### Terminal Multiplexers

**Screen** (`.screenrc`):
- Ctrl-b as prefix (like tmux)
- 30,000 line scrollback
- 256-color support
- Windows start at 1 (not 0)

**Tmux** (`.tmux.conf`):
- Minimal config, 256-color support

## Environment-Specific Files

- **Local-only config**: `~/.shell-local-conf` (sourced last, not tracked)
- **Secrets**: `~/.env` (sourced before bash_private.gpg)
- **Encrypted secrets**: `~/.bash_private.gpg` (decrypted if available)

## Installation

The `installer/install.sh` script can be used to set up the environment on a new system. It:
- Downloads and extracts dotfiles to `$HOME`
- Installs vim plugins via pathogen
- Sets up solarized dircolors

## Development Notes

- **No build system** - this is a configuration-only repository
- Shell functions use POSIX-compatible syntax where possible
- Prefer `[` over `[[` for portability (per README philosophy)
- Vi-mode keybindings are assumed throughout all configurations
- **Modular .bashrc.d structure**: All shell config is in `~/.bashrc.d/*.sh`
  - Files load in numeric order (00, 05, 10, 11, 15, 16, 17, 18, 19, 20)
  - To disable a file: rename to `*.sh.disabled`
  - To add new config: create a new numbered file
