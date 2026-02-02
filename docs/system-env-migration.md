# System Environment Migration Guide

This document describes the migration from hardcoded paths to shellbase system environment variables.

## Overview

The system environment configuration provides:
- **Portability**: Scripts work across different users and systems
- **Single point of control**: One file to customize for your environment
- **Backward compatibility**: Fallback to computed defaults if variables not set

## Before and After

### Before: Hardcoded Paths

```bash
# Script with hardcoded user "ecc"
CONFIG_FILE=/home/ecc/.config/kopia/repository.config
BACKUP_SOURCES=("/home/ecc")
sudo -u ecc ~/bin/backup-prepare.sh "$@"
```

### After: Environment Variables

```bash
# Script using system environment
: "${SHELLBASE_CONFIG_DIR:=$HOME/.config}"
: "${SHELLBASE_USER:=$(id -un)}"
: "${SHELLBASE_BIN_DIR:=$HOME/bin}"

CONFIG_FILE="${SHELLBASE_CONFIG_DIR}/kopia/repository.config"
BACKUP_SOURCES=("$SHELLBASE_USER_HOME")
sudo -u "$SHELLBASE_USER" "${SHELLBASE_BIN_DIR}/backup-prepare.sh" "$@"
```

## Migration Pattern

### Pattern 1: Simple Path Replacement

**Before:**
```bash
backup_dir="$HOME/Documents/system-info"
```

**After:**
```bash
backup_dir="${SHELLBASE_BACKUP_DIR:-$HOME/Documents/system-info}"
```

### Pattern 2: Username Reference

**Before:**
```bash
sudo -u ecc ~/bin/script.sh
```

**After:**
```bash
: "${SHELLBASE_USER:=$(id -un)}"
: "${SHELLBASE_BIN_DIR:=$HOME/bin}"
sudo -u "$SHELLBASE_USER" "${SHELLBASE_BIN_DIR}/script.sh"
```

### Pattern 3: Provider-Specific Paths (Cloud, etc.)

**Before:**
```bash
rsync -ah "$backup_dir" /home/ecc/Yandex.Disk/backup/
pwfile=/home/ecc/.ssh/kopia@yandex.pw
```

**After:**
```bash
# Require user override for provider-specific paths
: "${SHELLBASE_CLOUD_DIR:?ERROR: Set SHELLBASE_CLOUD_DIR in ~/.shellbase-system.env}"
: "${SHELLBASE_KOPIA_PASSWORD_FILE:?ERROR: Set SHELLBASE_KOPIA_PASSWORD_FILE in ~/.shellbase-system.env}"

rsync -ah "$backup_dir" "$SHELLBASE_CLOUD_DIR/backup/"
pwfile="$SHELLBASE_KOPIA_PASSWORD_FILE"
```

### Pattern 4: Dynamic Instance Names

**Before:**
```bash
case "$INSTANCE" in
ecc)
  BACKUP_SOURCES=("/home/ecc")
  ;;
esac
```

**After:**
```bash
case "$INSTANCE" in
"$SHELLBASE_USER")
  BACKUP_SOURCES=("$SHELLBASE_USER_HOME")
  ;;
esac
```

## Files Migrated

### Core Scripts
- `bin/backup-system-info.sh` - System info backup with cloud sync
- `bin/shadowcache.sh` - Tmpfs cache synchronization
- `bin/kopia-snapshot.sh` - Kopia backup snapshots

### Shell Configuration
- `.bashrc.d/04-system-env.sh` - **NEW**: System environment loader
- `.bashrc.d/19-apps.sh` - Kopia alias using dynamic config detection
- `.bashrc.d/20-local.sh` - Hug SCM activation using project root variable

### Systemd Services
- `etc/systemd/system/shadowcache.service` - Uses `${SHELLBASE_BIN_DIR}` with fallback
- `etc/systemd/system/btrfs-scrub-@.service` - Uses `${SHELLBASE_BIN_DIR}` with fallback

### Documentation
- `CLAUDE.md` - Added System Environment Configuration section
- `etc/systemd/system/README.md` - Cleaned hardcoded "ecc" references
- `docs/kopia-notes.md` - Generalized instance names
- `docs/backup-scripts-notes.md` - Generalized instance names

## Setting Up Your Environment

### Step 1: Create User Override

```bash
# Copy the example template
cp $SHELLBASE_REPO_DIR/etc/default/shellbase.example ~/.shellbase-system.env
```

### Step 2: Customize for Your Setup

Edit `~/.shellbase-system.env`:

```bash
# Example for user "john"
export SHELLBASE_USER="john"
export SHELLBASE_USER_HOME="/home/john"

# Example for different project directory
export SHELLBASE_PROJECT_ROOT="$HOME/Projects"
export SHELLBASE_REPO_DIR="$SHELLBASE_PROJECT_ROOT/dotfiles"

# Example for cloud provider
export SHELLBASE_CLOUD_DIR="$HOME/Dropbox"
export SHELLBASE_KOPIA_PASSWORD_FILE="$HOME/.ssh/kopia@dropbox.pw"
```

### Step 3: Reload Shell

```bash
# Source the system environment
source ~/.bashrc.d/04-system-env.sh

# Or start a new shell
exec bash
```

### Step 4: Verify

```bash
# Check variables are set
echo $SHELLBASE_USER
echo $SHELLBASE_USER_HOME
echo $SHELLBASE_PROJECT_ROOT
```

## Testing

Run the test script to verify your setup:

```bash
bin/test-system-env.sh
```

Expected output:
```
=== Testing System Environment ===
[OK] Loader exists
[OK] Template exists
[OK] SHELLBASE_USER is set
[OK] SHELLBASE_USER_HOME is set
[OK] SHELLBASE_REPO_DIR is a directory
[OK] SHELLBASE_BIN_DIR is a directory
=== Tests Complete ===
```

## Troubleshooting

### Variable Not Set

**Error**: `ERROR: SHELLBASE_USER not set`

**Solution**: Ensure `04-system-env.sh` is being loaded. Check that it's in `~/.bashrc.d/` and is executable.

### Provider-Specific Variable Required

**Error**: `ERROR: SHELLBASE_CLOUD_DIR not set. Set it in ~/.shellbase-system.env`

**Solution**: Add the required variable to `~/.shellbase-system.env`:

```bash
echo 'export SHELLBASE_CLOUD_DIR="$HOME/MyCloudProvider"' >> ~/.shellbase-system.env
```

### Script Uses Old Hardcoded Path

**Error**: Script still references `/home/ecc/`

**Solution**: The script may not have been migrated yet. Check if it's using the fallback pattern:

```bash
${SHELLBASE_VAR:-default_value}
```

### Systemd Service Fails

**Error**: Systemd service cannot find script

**Solution**: Ensure `EnvironmentFile=-%h/.shellbase-system.env` is set in the service file, or use the fallback pattern:

```ini
ExecStart=${SHELLBASE_BIN_DIR:-/home/%U/bin}/script.sh
```

## Backward Compatibility

All migrated scripts use the `${VAR:-default}` pattern, which means:
- If the variable is set, use it
- If not set, use the default value
- Existing setups continue to work without modification

## Rollback

If you need to rollback to hardcoded paths:

1. Remove or disable `04-system-env.sh`:
   ```bash
   mv ~/.bashrc.d/04-system-env.sh ~/.bashrc.d/04-system-env.sh.disabled
   ```

2. Restore scripts from git history:
   ```bash
   git checkout HEAD~1 -- bin/kopia-snapshot.sh
   ```

3. Reload shell:
   ```bash
   exec bash
   ```

## Future Enhancements

Potential improvements for the future:
- **Validation function**: Add `shellbase_validate_env()` to check configuration
- **Auto-migration script**: Create tool to migrate existing setups automatically
- **conf.d pattern**: Support `etc/default/shellbase.d/*.conf` for modularity
- **Integration tests**: Automated testing for all shellbase scripts

## References

- System environment loader: `.bashrc.d/04-system-env.sh`
- Tracked template: `etc/default/shellbase`
- Example configuration: `etc/default/shellbase.example`
- Main documentation: `CLAUDE.md`
