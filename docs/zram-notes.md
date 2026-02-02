# ZRAM Compressed Swap Notes

This document explains the ZRAM compressed swap configuration used on this system. ZRAM provides compressed swap in RAM, offering faster swap access than disk while still benefiting from compression.

---

## What is ZRAM?

ZRAM creates a compressed block device in RAM. When pages are swapped to zram, they are compressed and stored in memory. This means:

- **Faster than disk swap**: RAM access even when "swapped"
- **More effective RAM**: Compression ratios of 2-4x are typical
- **Reduced wear**: No SSD write cycles for swap

**Trade-off**: CPU overhead for compression/decompression (minimal with zstd).

---

## Current Configuration

### File: `/etc/default/pop-zram`

```bash
# Default: 16384M. Doubled to 64GB for large-memory system.
MAX_SIZE=32768

# Use 100% of available RAM for zram (dynamically calculated)
PORTION=100

# zstd compression: ~3.37x ratio, good speed/compression balance
ALGO=zstd

# Aggressively swap to zram (higher than default 60)
SWAPPINESS=180

# Enable writeback to disk swap when zram is full
CONFIG_ZRAM_WRITEBACK = y
```

### Current System State

```
Memory:  64 GB RAM
Swap:    93 GB total
         ├─ 65 GB zram (priority 1000, used first)
         └─ 32 GB disk swap (priority 50, fallback)
```

**Verification**:
```bash
cat /proc/swaps                    # Show swap devices and priorities
systemctl status pop-default-settings-zram.service
zramctl                            # Show zram stats
```

---

## Tuning Parameters Explained

### MAX_SIZE

Maximum zram device size in megabytes.

| Setting | RAM Used | Effect |
|---------|----------|--------|
| 16384 (default) | ~16 GB compressed | Conservative |
| **32768 (yours)** | ~32 GB compressed | Large memory systems |
| 65536 | ~64 GB compressed | Aggressive |

**Your choice (32768)**: Doubled from default. Suitable for systems with 64+ GB RAM where compression allows storing more working set than physical RAM.

**How it's calculated**:
```bash
# From /usr/bin/pop-zram-config
TOTAL=$(awk -v p=${PORTION} '/MemTotal/ {printf "%.0f", p * $2 / 102400}' /proc/meminfo)
SIZE=$(((TOTAL > MAX_SIZE)) && echo ${MAX_SIZE} || echo ${TOTAL})
```
- `PORTION=100` means 100% of RAM
- Capped at `MAX_SIZE` (32768 MB = 32 GB)

### PORTION

Percentage of RAM to allocate for zram (1-200).

| Value | Behavior |
|-------|----------|
| 50 | 50% of RAM |
| 100 (yours) | 100% of RAM (capped by MAX_SIZE) |
| 200 | 200% of RAM (overcommit, relies on compression) |

**Your choice (100)**: Standard. Allows zram to use all RAM, capped by MAX_SIZE.

### ALGO

Compression algorithm.

| Algorithm | Ratio | Speed | Use Case |
|-----------|-------|-------|----------|
| `lzo` | ~2.0x | Fastest | Low CPU |
| `lz4` | ~2.4x | Fast | Balanced |
| **`zstd` (yours)** | ~3.37x | Good | Best ratio/speed tradeoff |
| `842` | ~4.0x | Slow | Max compression |

**Your choice (zstd)**: Recommended default. Best compression ratio with acceptable speed.

### SWAPPINESS

Kernel's eagerness to swap (0-200).

| Value | Behavior |
|-------|----------|
| 1-10 | Avoid swap unless critical (traditional HDD thinking) |
| 60 | Default kernel value |
| **180 (yours)** | Aggressively swap to zram |
| 200 | Maximum aggressiveness |

**Why high swappiness with zram?**
- Zram is fast (RAM speed)
- Compressed pages free up physical RAM for cache
- More file cache = better performance
- **Different from disk swap**: High swappiness with zram ≠ slow system

**Pop!_OS default**: 180 (matched by your config)

### PAGE_CLUSTERS

Consecutive pages to read ahead (calculated automatically).

```bash
# From /usr/bin/pop-zram-config
PAGE_CLUSTERS=$(test zstd = ${ALGO} && echo 0 || echo 1)
```

- `zstd`: 0 (readahead disabled, better for zstd)
- Other algorithms: 1

**Why 0 for zstd?** ZSTD benefits less from readahead; disabling it improves IOPS.

---

## Swap Priority Strategy

```bash
# From /usr/bin/pop-zram-config
swapon -p 1000 /dev/zram0    # zram has highest priority
```

```
Priority 1000: /dev/zram0        ← Used first (compressed RAM)
Priority   50: /dev/dm-0         ← Disk swap fallback
```

**How it works**:
1. Kernel prefers zram (priority 1000)
2. Only uses disk swap when zram is full
3. Pages can be written back from zram to disk (CONFIG_ZRAM_WRITEBACK=y)

---

## Complementary VM Settings

### From `/etc/sysctl.d/10-pop-default-settings.conf`

```bash
vm.swappiness = 200                          # Maximum swap eagerness
vm.watermark_boost_factor = 0                # Disable watermark boost
vm.watermark_scale_factor = 125              # Fine-tuned watermark scaling
vm.dirty_bytes = 268435456                   # 256 MB dirty page limit
vm.dirty_background_bytes = 134217728        # 128 MB background writeback
```

**Purpose**: These settings optimize for zram:
- High swappiness: Use zram aggressively
- Watermark tuning: Prevent allocation stalls
- Dirty bytes: Control writeback frequency

---

## Monitoring ZRAM

### Check current usage

```bash
# Swap devices and priorities
cat /proc/swaps

# ZRAM device statistics
zramctl

# Memory breakdown
free -h

# Compression stats (for /dev/zram0)
cat /sys/block/zram0/compr_data_size   # Compressed size
cat /sys/block/zram0/orig_data_size    # Uncompressed size
cat /sys/block/zram0/mm_stat           # Memory usage stats
```

### Calculate compression ratio

```bash
compr=$(cat /sys/block/zram0/compr_data_size)
orig=$(cat /sys/block/zram0/orig_data_size)
echo "scale=2; $orig / $compr" | bc    # Ratio
```

### Monitor swap activity

```bash
# Watch swap usage in real-time
watch -n 1 'cat /proc/swaps'

# vmstat shows swap-in/out
vmstat 1

# Detailed memory info
vm.zram     # Not available; check /proc/meminfo for SwapCached
```

---

## ZRAM vs Traditional Swap

| Aspect | ZRAM | Disk Swap |
|--------|------|-----------|
| Speed | RAM speed | Disk I/O speed |
| Latency | Microseconds | Milliseconds |
| CPU cost | Compression | None |
| SSD wear | None | High write wear |
| Capacity | Limited by RAM | Limited by disk space |
| Use case | First-tier swap | Second-tier overflow |

**Best of both worlds**: Use zram first, disk swap as overflow.

---

## Troubleshooting

### ZRAM not working

```bash
# Check if module loaded
lsmod | grep zram

# Check if device exists
ls -l /dev/zram0

# Check service status
systemctl status pop-default-settings-zram.service

# View service logs
journalctl -u pop-default-settings-zram.service
```

### Poor compression ratio

**Expected ratios**:
- zstd: 3-4x on typical data
- Code/text: 4-6x
- Already compressed data: 1-1.5x

**If ratio is consistently < 2x**:
- May have lots of incompressible data (videos, already-compressed files)
- Consider checking what's being swapped: `cat /proc/vmstat | grep pswpin`

### System slow despite zram

**Check**:
```bash
# Are you hitting disk swap?
cat /proc/swaps   # If /dev/dm-0 shows significant usage, zram is full

# Is zram full?
zramctl           # Check DISKSIZE vs DISKUSED
```

**Solutions**:
- Increase `MAX_SIZE` if you have RAM to spare
- Check for memory leaks
- Consider reducing `swappiness` if disk swap is being used too much

### High CPU usage

**ZSTD compression uses CPU**. Check if zram is the cause:

```bash
# Check compression operations
cat /sys/block/zram0/num_reads
cat /sys/block/zram0/num_writes
```

**If CPU is high**:
- Try `ALGO=lz4` for lower CPU usage
- Reduce `swappiness` to swap less aggressively

---

## Performance Considerations

### When ZRAM Shines

- **Large working sets that don't fit in RAM**: Compressed swap keeps more data accessible
- **SSD systems**: Reduces write wear significantly
- **Memory-constrained VMs**: Effectively increases RAM capacity
- **Build systems**: Object files compress well (4-6x)

### When ZRAM May Not Help

- ** Mostly incompressible data**: Videos, encrypted data, already-compressed files
- **Abundant RAM**: If you never swap, zram does nothing
- **CPU-bound workloads**: Compression overhead may matter

### Benchmarks

On a system with zstd compression:

| Workload | Compression Ratio | Performance Impact |
|----------|-------------------|-------------------|
| General desktop | 3-4x | Positive (more cache) |
| Compilation | 4-6x | Positive (more cache) |
| Database | 2-3x | Neutral (depends on access pattern) |
| Media editing | 1-1.5x | Negative (CPU overhead) |

---

## Installation

### Pop!_OS (Current System)

ZRAM is configured via the `pop-default-settings-zram.service`:

```bash
# Configuration file
/etc/default/pop-zram

# Service
/usr/bin/pop-zram-config

# Enabled by default
systemctl status pop-default-settings-zram.service
```

### Manual ZRAM Setup (Non-Pop!_OS)

If moving to a non-Pop!_OS system, you'll need:

1. **Install zram-tools** or set up manually
2. **Create config** similar to `/etc/default/pop-zram`
3. **Systemd service** to run zram setup on boot
4. **Sysctl settings** for optimal tuning

Example manual setup (simplified):

```bash
# Load module
modprobe zram

# Create device
zramctl --size 32G --algorithm zstd /dev/zram0

# Format and enable
mkswap /dev/zram0
swapon -p 1000 /dev/zram0

# Tune sysctl
sysctl vm.swappiness=180
```

---

## Related Files

| File | Purpose |
|------|---------|
| `/etc/default/pop-zram` | ZRAM configuration (this system) |
| `/usr/bin/pop-zram-config` | Pop!_OS zram setup script |
| `/etc/sysctl.d/10-pop-default-settings.conf` | VM tuning for zram |
| `/etc/sysctl.d/20-dev-machine.conf` | Your customizations (inotify, IPv6) |

---

## References

- [ZRAM Kernel Documentation](https://www.kernel.org/doc/Documentation/blockdev/zram.txt)
- [Pop!_OS ZRAM Implementation](https://github.com/pop-os/default-settings)
- [ZSTD Benchmarks](https://github.com/facebook/zstd/blob/development/doc/zstd_compression_presets.md)
- [Linux Swap Tuning](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/managing_memory_and_swap_resources/index)
