# /etc/fstab Notes and Rationale

This document captures the design decisions, tuning research, and patterns used in `/etc/fstab`. Useful for reference when setting up new systems or understanding the current configuration.

---

## BTRFS Compression Level Benchmarks

### Why `compress-force=zstd:N`?

Zstandard (zstd) compression significantly reduces disk usage with minimal CPU overhead. The choice of level depends on the storage medium (SSD vs HDD) and workload (write-heavy vs read-heavy).

### SATA SSD Benchmarks

| Level | Write MBps | Read MBps | Size % |
|-------|-----------|-----------|--------|
| None  | 468       | 489       | 100    |
| 1     | 856       | 806       | 41     |
| 2     | 880       | 988       | 41     |
| **3** | **900**   | **971**   | **39** | ← Write-heavy sweet spot |
| 4     | 720       | 1026      | 39     |
| **5** | **715**   | **1045**  | **38** | ← Balanced (default choice) |
| 6     | 533       | 1045      | 37     |
| 7     | 501       | 1041      | 37     |

**Interpretation**:
- Level 3: Best for write-heavy workloads (maximum write throughput)
- Level 5: Good balance, excellent read speed
- Levels 6+: Diminishing returns on reads, significant write penalty

### SATA HDD Benchmarks

| Level | Write MBps | Read MBps | Size % |
|-------|-----------|-----------|--------|
| None  | 178       | 176       | 100    |
| 1     | 326       | 358       | 41     |
| 2     | 347       | 364       | 40     |
| 3     | 351       | 370       | 39     |
| 4     | 355       | 374       | 39     |
| **5** | **361**   | **383**   | **38** | ← HDD sweet spot |
| 6     | 354       | 379       | 37     |
| 7     | 365       | 380       | 37     |
| 8     | 354       | 387       | 37     |
| 9     | 329       | 386       | 37     |
| 10+   | Declining | ~385      | 37     |

**Interpretation**: HDDs benefit similarly from compression, with level 5-7 being optimal.

### Chosen Levels by Mount Point

| Mount Point | Level | Rationale |
|-------------|-------|-----------|
| `/`, `/home`, data volumes | `zstd:5` | Balanced performance/compression |
| `/var/log` | `zstd:14` | Logs compress extremely well; write speed less critical |
| `/volumes/APM-cache` | `zstd:5` | Cache storage; balance speed and space |

---

## Mount Options Explained

### Common BTRFS Options

```
defaults,noatime,compress-force=zstd:5,commit=120,noautodefrag,nodiscard
```

| Option | Purpose |
|--------|---------|
| `noatime` | Don't record file access times (reduces write I/O) |
| `compress-force=zstd:N` | Force compression (even for incompressible files) |
| `commit=120` | Sync to disk every 120 seconds instead of 5 (default) |
| `noautodefrag` | Disable auto defrag (unnecessary on SSD, expensive on HDD) |
| `nodiscard` | Disable TRIM (use periodic trim instead via systemd timer) |

**Why `commit=120`?**
- Reduces write amplification on SSDs
- Acceptable risk: 2 minutes of data loss on power failure
- BTRFS COW design makes this relatively safe

**Why `nodiscard`?**
- TRIM on every deletion is slow
- Prefer `fstrim.timer` (weekly TRIM) instead

### Tmpfs Options

```
tmpfs /home/ecc/.cache tmpfs noatime,nodev,nosuid,uid=ecc,gid=ecc,size=5100M,mode=0700 0 0
```

| Option | Purpose |
|--------|---------|
| `noatime` | No access time recording |
| `nodev` | No device nodes allowed |
| `nosuid` | Ignore setuid/setgid bits |
| `uid=ecc,gid=ecc` | Owned by user, not root |
| `size=5100M` | Limit RAM usage |
| `mode=0700` | Private, user-only access |

**Security**: `nodev` and `nosuid` are critical on world-writable tmpfs mounts like `/tmp`, `/var/tmp`, `/var/cache`.

---

## The Shadowcache Pattern

The `shadowcache.service` requires a specific tmpfs + bind mount arrangement:

### Problem
tmpfs is cleared on reboot, but cached data is valuable and speeds up applications.

### Solution
1. Mount persistent storage on `/volumes/APM-cache/`
2. Mount tmpfs on target (`/home/ecc/.cache`)
3. Bind mount subdirectory from persistent storage to tmpfs

**Example from fstab**:
```bash
# Persistent backing store
LABEL=APM-cache /volumes/APM-cache btrfs ... 0 1

# tmpfs for speed
tmpfs /home/ecc/.cache tmpfs ... 0 0

# Exception: bind mount kopia from persistent storage
/volumes/APM-cache/ecc-cache/kopia /home/ecc/.cache/kopia none bind 0 0

# Nested tmpfs for kopia's own temp directories
tmpfs /volumes/APM-cache/ecc-cache/kopia/cli-logs tmpfs ... 0 0
tmpfs /volumes/APM-cache/ecc-cache/kopia/content-logs tmpfs ... 0 0
```

**How shadowcache works**:
- **On boot**: `shadowcache.sh load` rsyncs from `/volumes/APM-cache/ecc-cache/` → `/home/ecc/.cache/`
- **Every 2 hours**: `shadowcache-periodic.timer` runs `save` to persist changes
- **On shutdown**: `shadowcache.service` runs `save` before unmounting

**Why bind mount kopia?**
Kopia maintains its own cache structure. The nested tmpfs mounts allow:
- Kopia repository metadata → persistent
- Kopia CLI logs → tmpfs (ephemeral)
- Kopia content logs → tmpfs (ephemeral)

---

## Tmpfs Sizing Guidelines

Based on actual usage patterns:

| Mount Point | Size | Rationale |
|-------------|------|-----------|
| `/home/ecc/.cache` | 5.1 GB | Browser caches, build artifacts, application data |
| `/tmp` | 16 GB | Large temporary files, compilation |
| `/var/tmp` | 2 GB | Longer-lived temp files |
| `/var/cache` | 5 GB | APT archives, flatpak data |

**How to calculate**:
1. Monitor actual usage over time: `du -sh /home/ecc/.cache`
2. Add 20-30% headroom
3. Consider RAM capacity (tmpfs competes with applications)

**Danger**: Oversizing tmpfs can cause OOM kills. Undersizing defeats the purpose.

---

## Subvolume Strategy

BTRFS subvolumes allow separate backup/snapshot policies and more flexible quota management.

### Examples from fstab

```bash
# Root subvolume
LABEL=MP600-popos-root / btrfs subvol=/,defaults,... 0 1

# Separate home subvolume
/dev/mapper/MP600-data /home btrfs subvol=home,defaults,... 0 2

# Application data in separate subvolumes
LABEL=APM-data /var/lib/docker btrfs subvol=var-lib-docker,...
LABEL=APM-data /var/lib/libvirt/images btrfs subvol=var-lib-libvirt-images,...
LABEL=APM-data /home/ecc/Games btrfs subvol=games,...
LABEL=APM-data /home/ecc/.local/share/Steam btrfs subvol=ecc-local-share-steam,...
```

**Benefits**:
- Can snapshot `/home` independently of `/`
- Can exclude Games from backups by excluding the subvolume
- Docker/libvirt get separate COW trees

**Naming convention**: `subvol=<name>` where name describes the purpose:
- `var-lib-*` for `/var/lib` contents
- `ecc-local-share-*` for user-specific flatpak/app data
- Descriptive names like `games`, `varlog`

---

## Bind Mount Patterns

Bind mounts create alternate access paths to the same data.

### Pattern 1: Convenience bind mounts

```bash
/volumes/WDC-data/downloads/downloads-2025 /home/ecc/Downloads none bind 0 0
/volumes/WDC-data/cloud/yandex-disk /home/ecc/Yandex.Disk none bind 0 0
/volumes/MP600-data/cloud/Dropbox /home/ecc/Dropbox none bind 0 0
```

**Why**: Keep data organized by volume (`/volumes/`) but access from home dir for convenience.

### Pattern 2: Read-only system backup

```bash
/etc /home/ecc/bind-mounts/system/etc none bind,ro 0 0
/boot /home/ecc/bind-mounts/system/boot none bind,ro 0 0
/sys/firmware/efi/efivars /home/ecc/bind-mounts/system/efivars none bind,ro 0 0
```

**Why**: Allow user to backup critical system files without root elevation. Read-only prevents accidental modification.

### Pattern 3: Flatpak data isolation

```bash
/volumes/APM-data/flatpak/ecc /home/ecc/.local/share/flatpak none bind 0 0
```

**Why**: Keep flatpak data on a separate BTRFS volume with different compression/snapshot policies.

---

## Swap Priority

```bash
/dev/mapper/WDC-cryptswap none swap defaults,pri=50 0 0
```

**Priority** (`pri=N`):
- Higher number = used first
- Multiple swap devices can have different priorities
- Example: Fast SSD swap at `pri=51`, HDD at `pri=50`

**Why multiple swap devices**:
- SSD swap: Faster but limited write cycles
- HDD swap: Slower but essentially unlimited endurance
- Prioritize SSD, fallback to HDD when full

---

## Useful Tools

### Analyze BTRFS usage
```
https://carfax.org.uk/btrfs-usage/
```
Calculate space usage, RAID overhead, and metadata ratios.

### Find disk identifiers
```bash
blkid                    # Show UUIDs and LABELs
lsblk -f                 # Filesystem info with tree view
file -s /dev/nvme0n1p1   # Identify filesystem type
```

### BTRFS subvolume management
```bash
btrfs subvolume list /   # List all subvolumes
btrfs subvolume show /   # Show subvolume info
btrfs scrub status /     # Check scrub status
```

### Monitor tmpfs usage
```bash
df -h | grep tmpfs       # Check usage
free -h                  # Verify available RAM
```

---

## References

- [fstab(5) man page](https://man7.org/linux/man-pages/man5/fstab.5.html)
- [BTRFS Wiki](https://btrfs.wiki.kernel.org/)
- [systemd.mount(5) man page](https://man7.org/linux/man-pages/man5/systemd.mount.5.html)
- [ZSTD Compression Levels](https://github.com/facebook/zstd/blob/development/doc/zstd_compression_presets.md)
