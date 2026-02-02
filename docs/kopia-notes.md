# Kopia Backup System Notes

This document describes the Kopia backup configuration using systemd user services. Kopia is a fast and secure open-source backup/restore tool that supports incremental backups, compression, encryption, and deduplication.

---

## Overview

The backup system uses **template-based systemd user services** to create multiple backup profiles (instances). Each instance can snapshot different sources with different schedules.

**Architecture**:
```
kopia-snapshot.sh (script)
    ↓
backup-kopia-@.service (template)
    ↓
backup-kopia-@ecc.timer (trigger)
```

---

## Files

### Script: `bin/kopia-snapshot.sh`

Main script that performs snapshots for a given instance.

**Usage**: `kopia-snapshot.sh <INSTANCE>`

**Supported instances**:

| Instance | Sources | Purpose |
|----------|---------|---------|
| `$SHELLBASE_USER` | `$HOME` (or `/home/$SHELLBASE_USER`) | Personal files and home settings |
| `system` | `/` | System configuration files |
| `music` | `$HOME/Music` | Music directory |
| `dev` | `$HOME/Projects`, `$HOME/github`, `$HOME/.Idea`, `$HOME/.PyCharm` | Development files |
| `games` | `$HOME/Games`, `$HOME/.local/share/Steam` | Game data |
| `vms` | `$HOME/VMs` | Virtual machine disk images |

> **Note**: The `$SHELLBASE_USER` instance (named `ecc` in the original) is the primary user backup. Customize the instance name to match your username.

**Key features**:
- Reads config from `$HOME/.config/kopia/repository.config`
- Password from `$HOME/.ssh/kopia@<provider>.pw` (e.g., `kopia@yandex.pw`)
- Calls `backup-prepare.sh` before snapshot
- Cleans up logs after snapshot (max 30 files, 10 MB)
- Calls `kopia-remote-sync.sh` after successful snapshot

**Special case**: When run as root, sets capabilities for kopia:
```bash
sudo setcap cap_dac_read_search=+ep $(which kopia)
```
This allows kopia to read all files as non-root user.

---

### Script: `bin/kopia-remote-sync.sh`

Syncs local Kopia repository to remote storage via rclone.

**Usage**: `kopia-remote-sync.sh <INSTANCE>`

**Configuration**:
- Remote path: `yandex:backup/kopia/main`
- Requires mountpoint at `~/bind-mounts/backup-kopia`
- Uses rclone with 32 transfer threads

**Instance behavior**:
- `$SHELLBASE_USER` (e.g., `ecc`): Exits immediately (no sync)
- All others: Syncs to remote

**Why skip sync for the primary user instance?**
The primary user backup is typically large and sync is handled separately or manually. Customize this behavior as needed.

---

### Systemd Template: `.config/systemd/user/backup-kopia-@.service`

Template service that runs `kopia-snapshot.sh` for any instance.

**Key settings**:
```bash
Type=oneshot
ExecStart=%h/bin/kopia-snapshot.sh %I
Nice=19                    # Lowest priority
LogRateLimitIntervalSec=0  # Don't rate limit logs
```

**Template specifiers**:
- `%h`: Home directory (expands to `/home/$USER` or equivalent)
- `%i`: Instance name (e.g., your username)
- `%I`: Same as `%i`

**How it works**:
When systemd starts `backup-kopia-@<instance>.service` (e.g., `backup-kopia-@ecc.service`), it runs:
```bash
~/bin/kopia-snapshot.sh <instance>  # e.g., ~/bin/kopia-snapshot.sh ecc
```

---

### Systemd Timer: `.config/systemd/user/backup-kopia-@<instance>.timer`

Triggers the backup service on a schedule.

**Example**: `backup-kopia-@ecc.timer` for a user named `ecc`

**Schedule**:
```bash
OnCalendar=*-*-* 8..23:00:00
Persistent=true
```

**Meaning**:
- Every hour from 8 AM to 11 PM
- `Persistent=true`: If system was off, runs on next boot

**Installation**:
```bash
# Enable the timer (user service) - replace <instance> with your instance name
systemctl --user enable backup-kopia-@<instance>.timer
systemctl --user start backup-kopia-@<instance>.timer

# Check status
systemctl --user list-timers
systemctl --user status backup-kopia-@<instance>.timer

# View logs
journalctl --user -u backup-kopia-@<instance>.service
```

---

## Kopia Configuration

### Repository Config

Located at: `$HOME/.config/kopia/repository.config`

This file contains connection details, encryption keys, and repository settings. **Keep this safe** - without it, you cannot access your backups.

### Environment Variables

The script sets these for kopia:

```bash
KOPIA_LOG_DIR_MAX_FILES=10           # Keep max 10 log files
KOPIA_CONTENT_LOG_DIR_MAX_FILES=10   # Keep max 10 content log files
KOPIA_PASSWORD=$(<"$pwfile")         # Repository password
```

This prevents log accumulation while keeping recent logs for debugging.

---

## Backup Strategy

### Local-First, Remote Sync

1. **Local snapshot** (fast, incremental):
   - Snapshot to local repository (likely on fast local storage)
   - Runs hourly (8 AM - 11 PM)
   - Minimal performance impact due to incremental nature

2. **Remote sync** (slower, offsite):
   - Uses rclone to sync repository to Yandex Disk
   - Runs after successful snapshot
   - Provides offsite backup

### Advantages

- **Fast snapshots**: Local repository on fast storage
- **Incremental**: Only changed data is stored
- **Deduplication**: Same files across snapshots stored once
- **Compression**: Reduced storage requirements
- **Encryption**: Repository is encrypted
- **Offsite copy**: Yandex Disk provides disaster recovery

---

## Setting Up on a New System

### 1. Install Kopia

```bash
# Download from https://kopia.io/download/
# or via package manager
```

### 2. Set Capabilities (Optional)

If you want to backup files you don't own as non-root user:

```bash
sudo kopia-snapshot.sh  # Sets cap_dac_read_search+ep
```

This allows kopia to read all files without running as root.

### 3. Create Repository Config

```bash
# Initialize repository (adjust command as needed)
kopia repository create from-config --config-file ~/.config/kopia/repository.config
```

### 4. Set Password File

```bash
# Store password securely
echo "your-password" > ~/.ssh/kopia@yandex.pw
chmod 600 ~/.ssh/kopia@yandex.pw
```

### 5. Copy Scripts

```bash
# From shellbase
cp bin/kopia-snapshot.sh ~/bin/
cp bin/kopia-remote-sync.sh ~/bin/
chmod +x ~/bin/kopia-*.sh
```

### 6. Install Systemd Units

```bash
# From shellbase
mkdir -p ~/.config/systemd/user/
cp .config/systemd/user/backup-kopia-@.service ~/.config/systemd/user/
cp .config/systemd/user/backup-kopia-@<instance>.timer ~/.config/systemd/user/

# Reload systemd
systemctl --user daemon-reload

# Enable timer (replace <instance> with your instance name)
systemctl --user enable backup-kopia-@<instance>.timer
systemctl --user start backup-kopia-@<instance>.timer
```

### 7. Customize

Edit `kopia-snapshot.sh` to match your setup:
- Change `CONFIG_FILE` path if needed
- Add/modify instances in the case statement
- Update `REMOTE_PATH` in `kopia-remote-sync.sh`
- Ensure rclone is configured for your remote storage

---

## Monitoring and Management

### Check Timer Status

```bash
# List all timers
systemctl --user list-timers

# Specific timer (replace <instance>)
systemctl --user status backup-kopia-@<instance>.timer
```

### View Logs

```bash
# Service logs (replace <instance>)
journalctl --user -u backup-kopia-@<instance>.service -e

# Follow logs
journalctl --user -u backup-kopia-@<instance>.service -f

# Kopia's own logs
ls ~/.cache/kopia/cli-logs/
ls ~/.cache/kopia/content-logs/
```

### Manual Snapshot

```bash
# Trigger immediately (replace <instance>)
systemctl --user start backup-kopia-@<instance>.service

# Or run script directly (replace <instance>)
~/bin/kopia-snapshot.sh <instance>
```

### Snapshot Management

```bash
# List snapshots
kopia snapshot list --config-file ~/.config/kopia/repository.config

# Restore
kopia snapshot restore <snapshot-id> --target /restore/path

# Delete old snapshots
kopia snapshot delete <snapshot-id>

# Estimate snapshot size
kopia snapshot estimate ~/Documents
```

---

## Troubleshooting

### Service Not Running

```bash
# Check if user systemd is running
loginctl show-user $USER | grep Linger

# Enable lingering (allows user services to run when logged out)
loginctl enable-linger $USER

# Check service status (replace <instance>)
systemctl --user status backup-kopia-@<instance>.service
```

### Snapshot Fails

**Check**:
```bash
# Is config file readable?
test -r ~/.config/kopia/repository.config

# Is password file readable?
test -r ~/.ssh/kopia@yandex.pw

# Test kopia connection
kopia snapshot list --config-file ~/.config/kopia/repository.config
```

### Sync Fails

**Check**:
```bash
# Is mountpoint present?
mountpoint ~/bind-mounts/backup-kopia

# Is rclone configured?
rclone listremotes

# Test rclone connection
rclone lsl yandex:backup/kopia/main
```

### Permission Denied

If kopia cannot read certain files:
```bash
# Set capabilities
sudo kopia-snapshot.sh

# Verify
getcap $(which kopia)
# Expected: cap_dac_read_search+ep
```

### Large Log Files

If logs accumulate:
```bash
# Manually clean
kopia logs cleanup --max-total-size-mb 10 --max-count 30

# Check log dirs
du -sh ~/.cache/kopia/cli-logs/
du -sh ~/.cache/kopia/content-logs/
```

---

## Customization Examples

### Add a New Instance

Edit `kopia-snapshot.sh`, add to case statement:

```bash
photos)
  BACKUP_SOURCES=("$HOME/Pictures")
  ;;
esac
```

Create timer for the new instance:
```bash
# Copy and edit timer (replace <instance> and <new-instance>)
cp .config/systemd/user/backup-kopia-@<instance>.timer \
   .config/systemd/user/backup-kopia-@<new-instance>.timer

# Edit schedule as needed
```

Enable:
```bash
systemctl --user enable backup-kopia-@<new-instance>.timer
```

### Change Schedule

Edit the timer file:

```bash
# Every 6 hours
OnCalendar=*-*-* 00,06,12,18:00:00

# Daily at 2 AM
OnCalendar=*-*-* 02:00:00

# Every 15 minutes (high-frequency backup)
OnCalendar=*-*-* *:00/15:00
```

### Add Remote Storage for Primary User Instance

Edit `kopia-remote-sync.sh` to enable sync for the primary user instance (e.g., `ecc`):
```bash
case "$INSTANCE" in
  <your-instance>)  # e.g., ecc
    # Remove "exit 0" to enable sync
    REMOTE_PATH="yandex:backup/kopia/<your-instance>"
    # ... rest of sync code
    ;;
esac
```

---

## Related Files

| File | Purpose |
|------|---------|
| `bin/kopia-snapshot.sh` | Main backup script |
| `bin/kopia-remote-sync.sh` | Remote sync via rclone |
| `.config/systemd/user/backup-kopia-@.service` | Template service |
| `.config/systemd/user/backup-kopia-@<instance>.timer` | Schedule trigger (e.g., `backup-kopia-@ecc.timer`) |
| `~/.config/kopia/repository.config` | Kopia repository config |
| `~/.ssh/kopia@<provider>.pw` | Repository password (e.g., `kopia@yandex.pw`) |
| `~/bin/backup-prepare.sh` | Pre-snapshot preparation (referenced) |

---

## Integration with Systemd Tmpfs

The Kopia repository may be on tmpfs or require special handling. See:
- [shadowcache service](../etc/systemd/system/README.md#shadowcacheservice) for tmpfs management
- [fstab notes](../docs/fstab-notes.md) for bind mount patterns

---

## References

- [Kopia Documentation](https://kopia.io/docs/)
- [Kopia SystemD Timer Setup](https://kopia.discourse.group/t/how-to-properly-schedule/2070/3)
- [rclone Documentation](https://rclone.org/)
- [rclone Yandex](https://rclone.org/yandex/)
- [systemd user services](https://www.freedesktop.org/software/systemd/man/latest/systemd.user.html)
