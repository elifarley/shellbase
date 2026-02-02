# Systemd Service Units

This directory contains systemd service and timer units for managing system-level services as part of the shellbase configuration.

## Services

### btrfs-scrub-@.service (template)

**Purpose**: Template service for scrubbing BTRFS filesystems to detect and repair data corruption.

**What it does**: Runs `btrfs scrub` on a specified volume. Scrubbing reads all data and metadata on the filesystem and verifies their checksums. If corrupted data is found and a redundant copy exists (RAID-1/5/6/10), BTRFS will automatically repair it.

**Template usage**: The `@` in the filename is a systemd specifier. When instantiated as `btrfs-scrub-@APM-data.service`, the `%i` specifier in the service file becomes `APM-data`.

**Resource-friendly**:
- `Nice=19`: Lowest process priority
- `CPUSchedulingPolicy=idle`: Only runs when CPU is idle
- `IOSchedulingClass=idle`: Only does I/O when disk is idle
- `ConditionACPower=true`: Only runs on AC power (laptops)

**Script**: `$SHELLBASE_BIN_DIR/btrfs-scrub.sh` (or `~/bin/btrfs-scrub.sh`)
```bash
btrfs scrub start -Bd -c 2 -n 4 /volumes/"$1"
```
- `-B`: Background mode (returns immediately, scrub runs asynchronously)
- `-d`: Print detailed statistics
- `-c 2`: Use 2 CPU threads for scrubbing
- `-n 4`: Read data 4 times (for verification)

**Related timers** (one per volume):
| Timer | Volume | Schedule |
|-------|--------|----------|
| `btrfs-scrub-@APM-data.timer` | `/volumes/APM-data` | Monthly |
| `btrfs-scrub-@CT500-data.timer` | `/volumes/CT500-data` | Monthly |
| `btrfs-scrub-@MP600-data.timer` | `/volumes/MP600-data` | Monthly |
| `btrfs-scrub-@ST1G-data.timer` | `/volumes/ST1G-data` | Monthly |
| `btrfs-scrub-@WDC-data.timer` | `/volumes/WDC-data` | Monthly |

**Schedule details**:
- `OnCalendar=monthly`: Runs on the first day of each month
- `RandomizedDelaySec=1200`: Random delay up to 20 minutes (prevents all volumes from scrubbing simultaneously)
- `Persistent=true`: If system was off during scheduled time, runs on next boot
- `AccuracySec=1h`: Timer can be delayed up to 1 hour for system efficiency

**Activation**:
```bash
# Enable all scrub timers
sudo systemctl enable btrfs-scrub-@*.timer
sudo systemctl start btrfs-scrub-@*.timer

# Check status of all scrubs
btrfs scrub status /volumes/*

# Manually trigger a scrub for testing
sudo systemctl start btrfs-scrub-@APM-data.service

# View logs
journalctl -u btrfs-scrub-@APM-data.service -f
```

---

### hblock.service + hblock.timer

**Purpose**: Ad and malware blocking by updating `/etc/hosts` with blocklists.

**What it does**: Downloads hosts file blocklists and merges them into `/etc/hosts`, blocking connections to known ad/malware/tracking domains. This is system-wide blocking that works for all browsers and applications.

**Source**: [hblock](https://github.com/hectorm/hblock) - lightweight POSIX shell script.

**Schedule**:
- `OnCalendar=*-*-* 00:00:00`: Runs daily at midnight
- `RandomizedDelaySec=3600`: Random delay up to 1 hour
- `Persistent=true`: Runs on next boot if scheduled time was missed

**Security hardening** (sandboxed service):
```
ProtectSystem=strict       # Read-only system filesystem
ProtectHome=yes            # No access to home directories
PrivateTmp=yes             # Private /tmp
PrivateDevices=yes         # No access to /dev
PrivateUsers=yes           # Runs as unprivileged user
ProtectKernelTunables=yes  # No kernel tunable access
ProtectKernelModules=yes   # No module loading
ProtectControlGroups=yes   # No cgroup access
RestrictAddressFamilies=AF_INET AF_INET6  # Network only
CapabilityBoundingSet=     # No capabilities
NoNewPrivileges=yes        # Cannot gain privileges
MemoryDenyWriteExecute=yes # No writable+executable memory
```

**How it works**:
1. Downloads blocklists to `RuntimeDirectory=/var/cache/hblock`
2. Writes merged blocklist to same location
3. `ExecStartPost` copies to `/etc/hosts`
4. Cleans up temporary file

**Activation**:
```bash
# Ensure hblock is installed
sudo apt install hblock  # or via other package manager

# Enable the timer
sudo systemctl enable hblock.timer
sudo systemctl start hblock.timer

# Check next run time
systemctl list-timers hblock.timer

# Manually update blocklists
sudo systemctl start hblock.service

# View logs
journalctl -u hblock.service -e
```

**Note**: If you don't use `hblock`, skip this service. It requires the `hblock` package to be installed.

---

### nvidia-config.service

**Purpose**: Configure NVIDIA RTX 3050 (secondary GPU) power management settings.

**What it does**:
1. Disables persistence mode (`-pm 0`) for GPU at `0000:28:00.0`
2. Removes power limit (`-pl 0`) - allows max performance
3. Drains and removes power state (`drain -p -m 1`)

**When it runs**:
- **After**: `nvidia-persistenced.service` (NVIDIA persistence daemon)
- **Type**: `oneshot` with `RemainAfterExit=yes` - runs once at boot, stays marked as active

**Activation**:
```bash
sudo systemctl enable nvidia-config.service
sudo systemctl start nvidia-config.service

# Check GPU status
nvidia-smi

# View logs
journalctl -u nvidia-config.service -e
```

**Note**: This is hardware-specific. If you don't have this exact GPU configuration, skip this service.

---

### shadowcache.service

**Purpose**: Synchronizes cache data between persistent storage and tmpfs filesystems.

**What it does**: This service addresses the problem of tmpfs (memory-backed) filesystems losing data on reboot. It provides bidirectional synchronization:

- **On boot (`load`)**: Copies cached data from persistent disk to tmpfs
- **On shutdown (`save`)**: Copies changed data back from tmpfs to persistent disk

**Locations synced**:
| Source (tmpfs) | Destination (persistent) | Size | Notes |
|----------------|-------------------------|------|-------|
| `~$SHELLBASE_USER/.cache/` | `/volumes/<your-volume>/$SHELLBASE_USER-cache/` | ~2 GB | User cache, excludes kopia |
| `/var/cache/` | `/volumes/<your-volume>/var-cache/` | ~2 GB | APT archives, excludes apt/archives on save |
| `/var/tmp/` | `/volumes/<your-volume>/var-tmp/` | Variable | Excludes flatpak-cache-* and systemd-private-* |

**When it runs**:
- **Start**: After `local-fs.target` (when filesystems are mounted)
- **Stop**: Before `shutdown.target` (during shutdown sequence)
- **TimeoutStopSec**: 600 seconds (10 minutes) - allows large rsync operations to complete

**Activation**:
```bash
# Enable the service (starts on boot)
sudo systemctl enable shadowcache.service

# Start immediately
sudo systemctl start shadowcache.service

# Check status
sudo systemctl status shadowcache.service
```

---

### shadowcache-periodic.service + shadowcache-periodic.timer

**Purpose**: Periodically saves tmpfs data to persistent storage (prevents data loss from crashes/power failures).

**What it does**: Runs the `save` operation every 2 hours, ensuring that if the system crashes or loses power unexpectedly, the most recent cache data (max 2 hours old) is preserved on disk.

**Timer schedule**:
- **OnBootSec**: 30 minutes after system boot
- **OnUnitActiveSec**: Every 2 hours after the last successful run

**Activation**:
```bash
# Enable the timer (starts on boot)
sudo systemctl enable shadowcache-periodic.timer

# Start the timer immediately
sudo systemctl start shadowcache-periodic.timer

# Check when it will next run
systemctl list-timers shadowcache-periodic.timer

# View timer logs
journalctl -u shadowcache-periodic.timer
```

---

## Installation (Symlink Approach)

The most elegant installation is to symlink from shellbase to the system:

```bash
# Symlink all service/timer files (adjust SHELLBASE_SRC to your location)
SHELLBASE_SRC="$HOME/IdeaProjects/shellbase"
sudo ln -sf "$SHELLBASE_SRC/etc/systemd/system/"*.service /etc/systemd/system/
sudo ln -sf "$SHELLBASE_SRC/etc/systemd/system/"*.timer /etc/systemd/system/

# Create per-volume timer symlinks for btrfs-scrub
# (Adjust volume names to match your /volumes/ layout)
sudo ln -sf "$SHELLBASE_SRC/etc/systemd/system/btrfs-scrub-@APM-data.timer" /etc/systemd/system/
sudo ln -sf "$SHELLBASE_SRC/etc/systemd/system/btrfs-scrub-@CT500-data.timer" /etc/systemd/system/
sudo ln -sf "$SHELLBASE_SRC/etc/systemd/system/btrfs-scrub-@MP600-data.timer" /etc/systemd/system/
sudo ln -sf "$SHELLBASE_SRC/etc/systemd/system/btrfs-scrub-@ST1G-data.timer" /etc/systemd/system/
sudo ln -sf "$SHELLBASE_SRC/etc/systemd/system/btrfs-scrub-@WDC-data.timer" /etc/systemd/system/

# Reload systemd daemon
sudo systemctl daemon-reload

# Enable services (choose based on your setup)
sudo systemctl enable nvidia-config.service           # If you have RTX 3050 secondary GPU
sudo systemctl enable shadowcache.service shadowcache-periodic.timer
sudo systemctl enable btrfs-scrub-@*.timer            # If using BTRFS
sudo systemctl enable hblock.timer                    # If using hblock for ad blocking
```

**Why symlinks?**
- Single source of truth (files live in git-tracked shellbase)
- Edit in shellbase, changes reflected immediately
- Easy to track changes and roll back

**Customizing for your system**:
- **btrfs-scrub timers**: Create timer files for your actual BTRFS volumes, named `btrfs-scrub-@<volume-name>.timer`
- **nvidia-config**: Only if you have this exact GPU configuration; edit the GPU PCI ID (`0000:28:00.0`) for your hardware
- **shadowcache**: Update volume paths in `../../bin/shadowcache.sh` to match your persistent storage location
- **hblock**: Requires `hblock` package; skip if not using

---

## Related Files

| File | Location | Purpose |
|------|----------|---------|
| `shadowcache.sh` | `../../bin/shadowcache.sh` | Script that performs tmpfs↔persistent rsync operations |
| `btrfs-scrub.sh` | `../../bin/btrfs-scrub.sh` | Script that runs btrfs scrub with optimized parameters |
| `pop-zram` | `../../etc/default/pop-zram` | ZRAM compressed swap configuration |
| `20-dev-machine.conf` | `../../etc/sysctl.d/20-dev-machine.conf` | Kernel parameter customizations |

## Related Documentation

| Document | Purpose |
|----------|---------|
| [../../docs/fstab-notes.md](../../docs/fstab-notes.md) | BTRFS tuning, mount options, tmpfs sizing |
| [../../docs/zram-notes.md](../../docs/zram-notes.md) | ZRAM compressed swap deep dive |
| [../../docs/sysctl-notes.md](../../docs/sysctl-notes.md) | System tuning and kernel parameters |

---

## Troubleshooting

### BTRFS Scrub

**Scrub not running**:
```bash
# Check if timer is active
systemctl list-timers btrfs-scrub-@*.timer

# Check service logs
journalctl -u btrfs-scrub-@APM-data.service -e

# Manually trigger for testing
sudo systemctl start btrfs-scrub-@APM-data.service

# Check scrub status
btrfs scrub status /volumes/APM-data
```

**Performance impact**: Scrub is designed to be low-priority. If you notice impact, verify:
- `ConditionACPower=true` prevents scrubbing on battery
- `IOSchedulingClass=idle` yields to other I/O
- `CPUSchedulingPolicy=idle` yields to other CPU tasks

### hblock

**Service fails**:
```bash
# Check if hblock is installed
which hblock

# Install if missing
sudo apt install hblock

# Test manually
hblock -O /tmp/hblock/hosts

# Check logs
journalctl -u hblock.service -e
```

**Blocking too much**: Edit `/etc/hblock.conf` or remove unwanted blocklist sources from the service's `ExecStart` command.

### shadowcache

**Service won't start**:
```bash
# Check logs
journalctl -u shadowcache.service -e

# Verify script exists and is executable
ls -l ~/bin/shadowcache.sh  # or $SHELLBASE_BIN_DIR/shadowcache.sh

# Test manually
~/bin/shadowcache.sh load  # or "save"
```

**Timer not firing**:
```bash
# Verify timer is active
systemctl list-timers --all

# Check timer logs
journalctl -u shadowcache-periodic.timer -e

# Manually trigger for testing
sudo systemctl start shadowcache-periodic.service
```

**Data not syncing**:
- Verify your persistent volume is mounted (e.g., `mount | grep <your-volume>`)
- Check rsync output in journalctl for errors
- Ensure permissions allow reading/writing source/destination directories

### nvidia-config

**Service fails**:
```bash
# Check logs
journalctl -u nvidia-config.service -e

# Verify GPU PCI ID
lspci | grep NVIDIA

# Test nvidia-smi commands manually
nvidia-smi -i 0000:28:00.0 -pm 0
nvidia-smi -pl 0 -i 0000:28:00.0
```

**Wrong GPU**: Edit the service file and replace `0000:28:00.0` with your GPU's PCI ID (find with `lspci | grep NVIDIA`).

---

## Systemd Concepts Used

### Template Units
Files named `@.service` or `@.timer` are templates. The `@` is replaced with an instance name:
- `btrfs-scrub-@.service` + instance `APM-data` → `btrfs-scrub-@APM-data.service`
- Inside the file, `%i` expands to the instance name (`APM-data`)

### Specifiers
Common systemd specifiers used in these units:
| Specifier | Expands to | Example |
|-----------|------------|---------|
| `%i` | Instance name | `APM-data` |
| `%n` | Full unit name | `btrfs-scrub-@APM-data.service` |
| `%C` | Cache directory | `/var/cache` |

### Service Types
| Type | Behavior | Use Case |
|------|----------|----------|
| `oneshot` | Runs once, success when command exits | Initialization tasks |
| `simple` | Runs continuously | Daemons |
| `oneshot` + `RemainAfterExit=yes` | Runs once, stays active | Boot-time configuration |

### Timer Triggers
| Setting | Meaning |
|---------|---------|
| `OnCalendar=monthly` | First day of each month |
| `OnBootSec=30min` | 30 minutes after boot |
| `OnUnitActiveSec=2h` | 2 hours after last activation |
| `Persistent=true` | Run on next boot if missed |
| `RandomizedDelaySec=3600` | Random delay up to 1 hour |
