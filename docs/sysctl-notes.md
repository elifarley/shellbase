# System Tuning (sysctl) Notes

This document explains custom kernel parameter settings via sysctl. These are stored in `/etc/sysctl.d/` and applied at boot.

---

## Custom Configurations

### File: `etc/sysctl.d/20-dev-machine.conf`

This file contains development machine customizations.

```bash
# Increase file watcher limits for IDEs and development tools
fs.inotify.max_user_watches=524288

# Disable IPv6 (for VPN compatibility)
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
```

---

## Settings Explained

### fs.inotify.max_user_watches

**Default**: 524288 (some distros: 8192)
**Your setting**: 524288

**What it does**: Limits how many files a single user can watch with `inotify`.

**Why it's needed**:
- IDEs (JetBrains, VS Code) watch files for live reload
- Language servers watch files for code analysis
- Build tools watch for changes
- Development tools often hit the default limit

**Symptoms of too low**:
- IDEs show "file watcher limits reached" warnings
- Live reload stops working
- Files don't refresh automatically

**How to calculate needed value**:

```bash
# Count current watches per user
find /proc/*/fd -lname 'anon_inode:inotify' 2>/dev/null \
  | xargs -I{} readlink -f /proc/{}/fd/* \
  | grep -c inotify
```

**Common recommendations**:
- Web development: 524288 (your setting)
- Heavy development: 1048576
- Kubernetes/Docker heavy: 2097152

---

## IPv6 Disable Settings

**Settings**:
```bash
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
```

**What it does**: Completely disables IPv6 on all interfaces.

**Why you have it**: Comment in file mentions Surfshark VPN compatibility.

**Risks**:
- Some applications expect IPv6 and may fail
- Services may need IPv6 (check logs)
- Not recommended for general use

**Alternatives**:
- Configure VPN to handle IPv6 properly
- Disable IPv6 only on VPN interface
- Use `sysctl` temporarily for testing: `sysctl -w net.ipv6.conf.all.disable_ipv6=1`

**To re-enable**:
```bash
sysctl -w net.ipv6.conf.all.disable_ipv6=0
sysctl -w net.ipv6.conf.default.disable_ipv6=0
```

---

## Pop!_OS Default Settings

### File: `/etc/sysctl.d/10-pop-default-settings.conf`

These are Pop!_OS defaults (not your customizations), but important to understand:

```bash
# Aggressive swapping for zram
vm.swappiness = 200

# Disable watermark boost (prevents allocation spikes)
vm.watermark_boost_factor = 0

# Fine-tuned watermark scaling
vm.watermark_scale_factor = 125

# Dirty page limits (in bytes, not pages)
vm.dirty_bytes = 268435456           # 256 MB
vm.dirty_background_bytes = 134217728 # 128 MB

# Maximum memory mappings per process
vm.max_map_count = 2147483642
```

### vm.swappiness

See [zram-notes.md](zram-notes.md) for detailed explanation. With zram, high swappiness is good.

### vm.watermark_boost_factor

**Default**: 0 (set by Pop!_OS)
**Kernel default**: Variable (often 15000)

**What it does**: Boosts low watermarks when system is under memory pressure.

**Why 0**: Disables boost to prevent allocation spikes. With zram, memory pressure is handled differently.

### vm.watermark_scale_factor

**Your setting**: 125
**Kernel default**: 10

**What it does**: Scales the gap between min and low watermarks.

**Effect**: Higher value = more reclaim triggered earlier = smoother behavior under pressure.

### vm.dirty_bytes / vm.dirty_background_bytes

**Your settings**:
- `vm.dirty_bytes = 268435456` (256 MB)
- `vm.dirty_background_bytes = 134217728` (128 MB)

**What they do**:
- `dirty_bytes`: Max dirty pages before processes are forced to write
- `dirty_background_bytes`: Max dirty pages before background writeback starts

**Traditional settings** (in percentages):
- `vm.dirty_ratio = 20` (20% of RAM)
- `vm.dirty_background_ratio = 10` (10% of RAM)

**Why bytes instead of percentages?**
- Predictable behavior regardless of RAM size
- On 64 GB system, 10% = 6.4 GB (too high for SSD wear)
- Fixed limits prevent excessive dirty data

**Effect**:
- Background writeback starts at 128 MB
- Forced writeback at 256 MB
- Better for SSD longevity (smaller write batches)

### vm.max_map_count

**Your setting**: 2147483642
**Default**: 65530

**What it does**: Maximum memory-mapped regions per process.

**Why set so high?**
- Required by some applications (Elasticsearch, games)
- Modern apps use many memory mappings
- High limit prevents "out of memory" errors

**Risks**: Each mapping uses kernel memory. Extremely high limits could allow abuse.

---

## Other sysctl.d Files (System Defaults)

### 10-kernel-hardening.conf

```bash
kernel.kptr_restrict = 1
```

**What it does**: Restricts kernel pointer exposure in `/proc/kallsyms`, `/proc/modules`, etc.

**Values**:
- 0: All users can see
- 1: Root only (your setting)
- 2: Nobody (even root)

**Why**: Makes kernel exploitation harder.

### 10-zeropage.conf

```bash
vm.mmap_min_addr = 65536
```

**What it does**: Prevents allocating memory at address 0 (NULL pointer dereference protection).

### 10-ptrace.conf

Controls `ptrace` scope for debugging.

---

## How to Apply Changes

### Temporary (until reboot)

```bash
sysctl -w fs.inotify.max_user_watches=524288
sysctl -w net.ipv6.conf.all.disable_ipv6=1
```

### Permanent

Edit file in `/etc/sysctl.d/` and reload:

```bash
sudo editor /etc/sysctl.d/20-dev-machine.conf
sudo sysctl --system          # Reload all sysctl.d files
sudo sysctl -p /etc/sysctl.d/20-dev-machine.conf  # Reload specific file
```

### Verify current value

```bash
sysctl fs.inotify.max_user_watches
sysctl net.ipv6.conf.all.disable_ipv6
```

---

## File Loading Order

Files in `/etc/sysctl.d/` are loaded in **lexical order** (alphabetical):

1. `10-*.conf` - System defaults (run first)
2. `20-*.conf` - Customizations (run after, can override)
3. `99-*.conf` - Final overrides (run last)

**Example**:
```
10-pop-default-settings.conf    # Sets vm.swappiness = 10
20-dev-machine.conf             # (doesn't override vm.swappiness)
Result: vm.swappiness = 10 (from 10-*.conf)
```

**Note**: Later files override earlier settings for the same key.

---

## Finding What to Tune

### See all current settings

```bash
sysctl -a                       # Show all (huge)
sysctl -a | grep vm.            # VM settings
sysctl -a | grep fs.inotify     # File system settings
```

### Get default value

```bash
sysctl -n -d <key>              # Show default (if available)
# or
cat /proc/sys/<category>/<key>  # Read from procfs
```

### See documentation

```bash
man sysctl                      # sysctl command
man sysctl.conf                 # Configuration format
```

---

## Monitoring

### Watch sysctl changes

```bash
# Monitor vm stats
vmstat 1

# Watch swap activity
watch -n 1 'cat /proc/vmstat | grep pswp'

# Check inotify usage
find /proc/*/fd -lname 'anon_inode:inotify' -printf '%p\n' 2>/dev/null | wc -l
```

---

## Troubleshooting

### Changes not taking effect

```bash
# Check if file is loaded
sysctl --system --verbose

# Check for syntax errors
sysctl -p /etc/sysctl.d/20-dev-machine.conf

# Check if override by later file
grep -r "SETTING" /etc/sysctl.d/
```

### IDE file watcher issues

```bash
# Check current limit
cat /proc/sys/fs/inotify/max_user_watches

# Check current usage
find /proc/*/fd -lname 'anon_inode:inotify' 2>/dev/null | wc -l

# Temporarily increase
sysctl -w fs.inotify.max_user_watches=1048576
```

### IPv6 needed after disabling

```bash
# Re-enable temporarily
sysctl -w net.ipv6.conf.all.disable_ipv6=0

# Bring interface up
ip -6 addr show                 # Check IPv6 addresses
ip -6 route show                # Check routes
```

---

## Shellbase Integration

To apply these customizations on a new system:

```bash
# Symlink config files
sudo ln -sf /home/ecc/IdeaProjects/shellbase/etc/sysctl.d/20-dev-machine.conf /etc/sysctl.d/

# Apply settings
sudo sysctl --system
```

**Note**: Pop!_OS's `10-pop-default-settings.conf` is distro-specific. On other distros, you may need to manually set the VM tuning values.

---

## References

- [sysctl(8) man page](https://man7.org/linux/man-pages/man8/sysctl.8.html)
- [sysctl.conf(5) man page](https://man7.org/linux/man-pages/man5/sysctl.conf.5.html)
- [Kernel Documentation: sysctl](https://www.kernel.org/doc/Documentation/sysctl/)
- [inotify(7) man page](https://man7.org/linux/man-pages/man7/inotify.7.html)
- [ZRAM Notes](zram-notes.md) - For vm.swappiness and related settings
