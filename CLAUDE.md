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
├── 04-system-env.sh   - System environment variables (SHELLBASE_USER, paths)
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

### System Environment Configuration

Shellbase uses a system environment configuration to avoid hardcoded paths and enable cross-user portability:

- **Loader**: `.bashrc.d/04-system-env.sh` (loads with fallback chain)
- **Template**: `etc/default/shellbase` (tracked, provides defaults)
- **User override**: `~/.shellbase-system.env` (not tracked, personal customizations)

**Loading Priority**:
1. `~/.shellbase-system.env` (user override, highest priority)
2. `$SHELLBASE_REPO_DIR/etc/default/shellbase` (tracked template)
3. Computed defaults (lowest priority)

**Variables Available**:
```bash
SHELLBASE_USER              # Username (e.g., ecc)
SHELLBASE_USER_HOME         # User home directory (e.g., /home/ecc)
SHELLBASE_PROJECT_ROOT      # Base project directory ($HOME/IdeaProjects)
SHELLBASE_REPO_DIR          # Shellbase repository location
SHELLBASE_BIN_DIR           # User scripts directory ($HOME/bin)
SHELLBASE_REPO_BIN_DIR      # Repo scripts directory
SHELLBASE_BACKUP_DIR        # System info backup location
SHELLBASE_CACHE_DIR         # Cache directory
SHELLBASE_CONFIG_DIR        # Configuration directory
```

**Usage in Scripts**:
```bash
# Use with fallback for backward compatibility
backup_dir="${SHELLBASE_BACKUP_DIR:-$HOME/Documents/system-info}"

# Validate required variable
: "${SHELLBASE_USER:?ERROR: SHELLBASE_USER not set}"

# For provider-specific paths (cloud sync, etc.), require user override:
: "${SHELLBASE_CLOUD_DIR:?ERROR: Set SHELLBASE_CLOUD_DIR in ~/.shellbase-system.env}"
```

**Setup for New Users**:
```bash
# Copy the example to your home directory
cp $SHELLBASE_REPO_DIR/etc/default/shellbase.example ~/.shellbase-system.env

# Edit to customize for your environment
vim ~/.shellbase-system.env
```

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

## Critical Infrastructure Scripts

### shadowcache.sh - Tmpfs/Persistent Storage Sync

**Purpose**: Bidirectional synchronization between tmpfs (RAM) and persistent SSD storage.

**Architecture**: Hybrid approach with two sync strategies:

1. **Rsync-based hot data**: Frequently accessed cache directories sync on boot/shutdown
   - User cache (`~/.cache/` → `<persistent>/ecc-cache/`)
   - System cache (`/var/cache/` → `<persistent>/var-cache/`)
   - Temp files (`/var/tmp/` → `<persistent>/var-tmp/`)

2. **Bind-mount cold data**: Large/rarely-accessed directories mounted directly to SSD
   - `~/.cache/kopia` → `<persistent>/ecc-cache/kopia`
   - `~/.cache/ms-playwright` → `<persistent>/large-caches/ms-playwright`
   - `~/.cache/puppeteer` → `<persistent>/large-caches/puppeteer`
   - `~/.cache/uv/archive-v0` → `<persistent>/large-caches/uv-archive-v0`

**Why hybrid?** Bind mounts avoid:
- Wasting tmpfs space on large archives (600MB+ browser binaries)
- Slow rsync operations on write-once data
- Boot/shutdown delays for rarely-accessed data

**Commands**:
```bash
# User scope (handles ~/.cache/)
shadowcache.sh user-load [--dry-run]
shadowcache.sh user-save [--dry-run]
shadowcache.sh user-status
shadowcache.sh user-validate
shadowcache.sh user-stats              # Show user cache metrics only

# System scope (handles /var/cache, /var/tmp)
shadowcache.sh system-load [--dry-run]
shadowcache.sh system-save [--dry-run]
shadowcache.sh system-status
shadowcache.sh system-validate
shadowcache.sh system-stats            # Show system cache metrics only

# Combined (legacy commands)
shadowcache.sh stats                   # Show all metrics (both scopes)
```

**Metrics tracking**: Each sync operation logs SSD writes to CSV with 85% confidence interval (BTRFS zstd:5 compression).
- User metrics: `$PERSISTENT/${CACHE_USER}-cache/.shadowcache-metrics.csv`
- System metrics: `$PERSISTENT/.shadowcache-metrics.csv`
- Rotated via logrotate config (30-day retention)

### Backup Scripts

**kopia-snapshot.sh** (`bin/kopia-snapshot.sh <INSTANCE>`):
- Takes instance-specific snapshots (user, system, music, dev, games, vms)
- Syncs local repository to remote repository
- Uses `~/.config/kopia/repository.config`

**backup-prepare.sh** (`bin/backup-prepare.sh`):
- Creates CACHEDIR.TAG files in cache directories (backup exclusion)
- Excludes container overlay storage (~/.local/lib/containers/storage/vfs)
- Runs before backup operations to mark cache directories

**backup-system-info.sh** (`bin/backup-system-info.sh`):
- Backs up system configuration (installed packages, hardware info, etc.)
- Uses `SHELLBASE_BACKUP_DIR` for destination
- Optional cloud sync via `SHELLBASE_CLOUD_DIR`

### System Maintenance Scripts

**btrfs-scrub.sh** (`bin/btrfs-scrub.sh <volume>`):
- BTRFS data integrity scrub with optimized parameters
- Used by systemd template service `btrfs-scrub-@.service`
- Monthly schedule via per-volume timers

## Systemd Service Architecture

### Service Scopes

**User services** (`~/.config/systemd/user/`):
- Run without root, per-user instance
- Cannot use `User=` directive (already run as user)
- Example: `backup-kopia-@.service`

**System services** (`etc/systemd/system/`):
- Run as root, system-wide
- Example: `shadowcache-system.service`

### Template Services

Files with `@.service` are template units. Instance name replaces `%i`:
- `shadowcache-user@.service` + instance `ecc` → `shadowcache-user@ecc.service`
- `ExecStart=/home/%i/bin/shadowcache.sh` becomes `/home/ecc/bin/shadowcache.sh`

**Template services available**:
- `shadowcache-user@.service` - User cache sync (instance = username)
- `shadowcache-system.service` - System cache sync (no template)
- `btrfs-scrub-@.service` - BTRFS scrub (instance = volume name)
- `hblock.service` - Ad blocking via `/etc/hosts` updates

### Installation (Symlink Method)

**User services** (run as user):
```bash
ln -sf "$SHELLBASE_REPO_DIR/.config/systemd/user/shadowcache-user@.service" ~/.config/systemd/user/
ln -sf "$SHELLBASE_REPO_DIR/.config/systemd/user/shadowcache-user@.timer" ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable shadowcache-user@${USER}.service
```

**System services** (run as root):
```bash
# Symlink service and timer
sudo ln -sf "$SHELLBASE_REPO_DIR/etc/systemd/system/shadowcache-system.service" /etc/systemd/system/
sudo ln -sf "$SHELLBASE_REPO_DIR/etc/systemd/system/shadowcache-system.timer" /etc/systemd/system/

# Symlink wrapper script (for portability)
sudo ln -sf "$SHELLBASE_REPO_DIR/etc/systemd/system/shadowcache-system-wrapper.sh" /usr/local/sbin/shadowcache-system

sudo systemctl daemon-reload
sudo systemctl enable shadowcache-system.service
```

**Why symlinks**: Single source of truth in git, easy updates, trackable changes.

**Systemd Specifier Lessons**:
- User services: Use `%h` specifier for home directory (expands to user's home)
- System services: No `%h` available - use wrapper script that sources `SHELLBASE_USER`
- The wrapper at `/usr/local/sbin/shadowcache-system` reads from `$PERSISTENT/.shellbase-system.env`
- This enables full portability - repo-tracked service files work for any user via configuration

### Timer Schedules

| Timer | Schedule | Purpose |
|-------|----------|---------|
| `shadowcache-user@*.timer` | Every 4 hours (`OnCalendar=*:00/4:00`) | Periodic user cache save |
| `shadowcache-system.timer` | Every 6 hours (`OnCalendar=*:00/6:00`) | Periodic system cache save |
| `btrfs-scrub-@*.timer` | Monthly | BTRFS data integrity check |
| `hblock.timer` | Daily at midnight | Update ad blocklists |

**Why OnCalendar vs OnUnitActiveSec**: OnCalendar provides predictable scheduling with visible next run time in `systemctl list-timers`. OnUnitActiveSec (relative to last completion) can get stuck if the service never runs.

## Kitty Terminal Configuration

Kitty configs are in `.config/kitty/`:
- `kitty.conf` - Main configuration
- `current-theme.conf` - Color theme (can be changed via live reload)
- `choose-files.conf` - File chooser kitten configuration

**Key features**:
- Modular includes via `include` directive
- Vi-mode keybindings assumed throughout
- Dynamic theme switching supported

## Logrotate Configuration

Config files in `etc/logrotate.d/`:
- `shadowcache-metrics` - Rotates metrics CSV (daily, 30-day retention)

Install: `sudo cp etc/logrotate.d/* /etc/logrotate.d/`

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
  - Files load in numeric order (00, 04, 05, 10, 11, 15, 16, 17, 18, 19, 20)
  - To disable a file: rename to `*.sh.disabled`
  - To add new config: create a new numbered file
- **System environment variables**: Always use `SHELLBASE_*` variables with `${VAR:-default}` fallback pattern for portability

## Common Commands

### Systemd Service Management

```bash
# Install systemd services (user and system)
make install-all          # Install both user and system services
make install-user         # Install user services only (no sudo)
make install-system       # Install system services (requires sudo)

# Verify installation
make verify-all           # Verify all services are correctly installed
make doctor               # Check prerequisites

# Uninstall
make uninstall-all        # Remove all installed services
```

### Shadowcache Operations

```bash
# User cache (handles ~/.cache/)
shadowcache.sh user-load [--dry-run]     # Load from persistent storage
shadowcache.sh user-save [--dry-run]     # Save to persistent storage
shadowcache.sh user-status               # Show status
shadowcache.sh user-stats                # Show SSD write statistics

# System cache (handles /var/cache, /var/tmp)
shadowcache.sh system-load [--dry-run]   # Load from persistent storage
shadowcache.sh system-save [--dry-run]   # Save to persistent storage
shadowcache.sh system-status             # Show status
shadowcache.sh system-stats              # Show SSD write statistics

# Combined (legacy)
shadowcache.sh status                    # Show status for all caches
shadowcache.sh stats                     # Show all statistics
```

### Timer Configuration

Shadowcache timers use `OnCalendar` for predictable scheduling:
- User cache: Every 4 hours (`OnCalendar=*:00/4:00`)
- System cache: Every 6 hours (`OnCalendar=*:00/6:00`)

To adjust intervals, edit the timer files:
- User: `.config/systemd/user/shadowcache-user@.timer`
- System: `etc/systemd/system/shadowcache-system.timer`

Then reinstall: `make install-user` or `make install-system`

### Metrics Analysis

Shadowcache tracks SSD writes with BTRFS compression estimates (85% CI). After collecting data:

```bash
# View stats to analyze write patterns
shadowcache.sh user-stats    # User cache metrics only
shadowcache.sh system-stats  # System cache metrics only

# Check data range and average per operation
# Adjust timer intervals based on daily write volume
```

**Interval guidance** (based on avg writes per sync):
- < 50 MB/day → 6h interval (system cache)
- 50-200 MB/day → 4h interval (user cache)
- 200-500 MB/day → 2h interval
- > 500 MB/day → 1h interval
