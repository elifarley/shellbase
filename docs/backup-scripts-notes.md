# Backup Preparation Scripts

This document describes the backup preparation scripts used by the Kopia backup system. These scripts prepare the system before snapshots by tagging cache directories and saving system state.

---

## Scripts

### backup-prepare.sh

**Purpose**: Tag cache and temporary directories so backup software (like Kopia, Borg, rsync) can exclude them.

**What it does**:
1. Calls `backup-system-info.sh` to save package lists and system info
2. Creates `CACHEDIR.TAG` files in cache directories
3. Recursively finds and tags cache directories within specified base paths

**How it works**: Uses the [CACHEDIR.TAG](https://bford.info/cachedir/) specification. Backup software that respects this spec will skip directories containing this tag file.

**Signature**:
```
Signature: 8a477f597d28d172789f06886806bc55
```

This signature is the standard recognized by backup tools.

**Instance-specific behavior**:
```bash
test "$1" != <primary-instance> && exit 0
```
Only runs when the instance name matches your primary instance (e.g., `ecc`). Other instances (system, music, dev, etc.) skip preparation.

> **Note**: Customize `<primary-instance>` to match your primary backup instance name.

---

#### Functions

**create_cachedir_tag()**
Creates a CACHEDIR.TAG file in the specified directory.

```bash
create_cachedir_tag <directory>
```

- Creates tag file if it doesn't exist
- Skips if tag already exists
- Shows created file with `ls -l`

**list_cache_directories()**
Lists cache directories within a base directory that don't have CACHEDIR.TAG.

```bash
list_cache_directories <base_directory>
```

- Finds directories matching `*cache*`, `tmp*`, `*tmp` (case-insensitive)
- Excludes directories that already have CACHEDIR.TAG
- Outputs relative paths

---

#### Directories Tagged

**Explicitly tagged** (first loop):
- `~/.local/share//ubuntu*` (Ubuntu Steam apps)
- `~/.Idea*` (JetBrains IDEs)
- `~/apps/idea-*` (More IDEs)
- `~/.PyCharm*` (PyCharm)
- `~/.sylpheed*` (Email client)
- `~/ubuntu*` (Ubuntu app data)

**Explicitly tagged** (second loop):
- `~/.cache`
- `~/.local/share/Trash`
- `~/.local/share/tracker`
- `~/.local/share/JetBrains`
- `~/.local/share/lutris/runners`, `runtime`
- `~/.local/share/Steam/steamapps`, `package`, `logs`
- `~/.local/share/flatpak/repo/objects`, `app`, `runtime`
- `~/.m2` (Maven)
- `~/.dcrd` (Decred wallet)
- `~/.rustup` (Rust toolchain)
- `~/.mozilla/firefox`
- `~/.gradle/wrapper`
- `~/.cargo` (Rust crates)
- `~/.dashcore` (Dash wallet)
- `~/.pivx` (PIVX wallet)
- `~/.electron`
- `~/.ipfs`
- `~/.minikube/machines`
- `~/linux32`
- `~/Downloads`, `Music`, `Games`, `Dropbox`, `Yandex.Disk`, `Videos`
- `~/VirtualBox VMs`
- `~/bind-mounts`

**Recursively searched** (third loop):
For each base directory, finds all `*cache*`, `tmp*` directories:
- `~/.config`
- `~/.local`
- `~/.var`
- `~/.minikube`
- `~/.gradle`
- `~/.PyCharm*`
- `~/.nv` (NVIDIA)
- `~/.npm`
- `~/.openjfx`
- `~/.mcf`
- `~/.FBReader`

---

### backup-system-info.sh

**Purpose**: Save system package lists and configuration to help restore a system after disaster.

**What it saves**:
| File | Content | Purpose |
|------|---------|---------|
| `app-list-flatpak.txt` | `flatpak list` | Flatpak applications |
| `app-list-snap.txt` | `snap list` | Snap packages |
| `app-list-apt.txt` | `apt list --installed` | APT/deb packages |
| `ppa.txt` | `/etc/apt/sources.list*` | Custom package repositories |
| `hosts.txt` | `/etc/hosts` (without headers) | Host file entries |

**Location**: `~/Documents/system-info/`

**Cloud sync**: Copies to `~/Yandex.Disk/backup/` via rsync

---

#### Functions

**update_if_changed()**
Updates target file only if source content differs.

```bash
update_if_changed <source_command> <target_file>
```

**Behavior**:
- Creates file if it doesn't exist
- If content differs, shows diff of additions/removals
- If content same, skips update (no modification time change)
- Uses temporary file for atomic updates

---

### kill-tracker.sh

**Purpose**: Kill GNOME Tracker file indexer and clear its cache.

**What it does**:
1. Kills all Tracker processes: miner-apps, extract, miner-fs, store
2. Shows cache size before deletion
3. Removes cache directory: `~/.cache/tracker/`

**Why use it**:
- Tracker can consume significant CPU and disk space
- Cache can become corrupted
- Useful before backup (don't want to index changing cache)

**Safe**: Exits if tracker directory doesn't exist.

---

## Usage

### In Kopia Backup Workflow

**From `kopia-snapshot.sh`**:
```bash
sudo -u $SHELLBASE_USER ~/bin/backup-prepare.sh "$@" || exit
```

This runs preparation before each snapshot. Replace `$SHELLBASE_USER` with your username.

### Manual Usage

```bash
# Prepare for backup (tags caches, saves system info)
~/bin/backup-prepare.sh <instance>  # Replace <instance> with your instance name (e.g., ecc)

# Just save system info
~/bin/backup-system-info.sh

# Kill tracker and clear cache
~/bin/kill-tracker.sh
```

---

## CACHEDIR.TAG Specification

The [CACHEDIR.TAG spec](https://bford.info/cachedir/) allows applications to mark directories as cache. Backup software that supports this:

**Supported by**:
- Kopia
- Borg
- rsync (with `--caching`)
- Duplicity
- Many others

**Format**:
```
Signature: 8a477f597d28d172789f06886806bc55
```

**Requirements**:
- Must be a regular file
- Must start with exactly this signature
- Can contain additional comments (ignored)

**Minimum tag file**:
```
Signature: 8a477f597d28d172789f06886806bc55
```

**With explanation**:
```
Signature: 8a477f597d28d172789f06886806bc55

# This directory contains cache data that can be safely
# excluded from backups. Recreating this data from
# scratch will not lose any user data.
```

---

## Customization

### Adding Directories to Tag

Edit `backup-prepare.sh`, add to the loops:

```bash
# For single directories
for cachedir in ~/.my-new-cache-dir
do
  test -d "$cachedir" || continue
  create_cachedir_tag "$cachedir" || exit
done

# For recursive search
for base_dir in .my-new-base-dir
do
  test -f ~/"$base_dir"/CACHEDIR.TAG && continue
  while read -r line; do
    create_cachedir_tag ~/"$base_dir/$line"
  done <<< "$(list_cache_directories ~/"$base_dir")"
done
```

### Changing System Info Location

Edit `backup-system-info.sh`:

```bash
backup_dir="$HOME/alternative/path/system-info"
```

### Adding to Cloud Sync

Edit the rsync line in `backup-system-info.sh`:

```bash
rsync -ah "$backup_dir" /path/to/your/cloud/backup/
```

---

## Systemd Integration

### Kill Tracker on Boot

If you don't want Tracker running, there's already a systemd user unit:

```
~/.config/systemd/user/kill-tracker.service
~/.config/systemd/user/kill-tracker.timer
```

**Enable**:
```bash
systemctl --user enable kill-tracker.timer
systemctl --user start kill-tracker.timer
```

---

## Troubleshooting

### backup-prepare.sh Skips Everything

**Issue**: Script exits immediately

**Cause**: Instance name doesn't match your configured primary instance

**Fix**: Pass the correct instance name (replace `<instance>` with your instance):
```bash
~/bin/backup-prepare.sh <instance>  # e.g., ~/bin/backup-prepare.sh ecc
```

### CACHEDIR.TAG Not Created

**Issue**: Tag files not appearing

**Check**:
```bash
# Verify directory exists
test -d ~/.cache && echo "exists"

# Check permissions
ls -ld ~/.cache

# Try manual creation
echo "Signature: 8a477f597d28d172789f06886806bc55" > ~/.cache/CACHEDIR.TAG
```

### System Info Not Saving

**Issue**: `backup-system-info.sh` fails silently

**Check**:
```bash
# Verify backup directory
ls -la ~/Documents/system-info

# Test individual commands
flatpak list | head
snap list | head
apt list --installed | head
```

### Tracker Keeps Coming Back

**Issue**: Tracker restarts after being killed

**Solution**: Disable the service:
```bash
systemctl --user mask tracker-miner-apps.service
systemctl --user mask tracker-miner-fs.service
systemctl --user mask tracker-store.service
```

---

## Related Files

| File | Purpose |
|------|---------|
| `bin/kopia-snapshot.sh` | Calls backup-prepare.sh before snapshot |
| `bin/backup-prepare.sh` | Tags cache directories, saves system info |
| `bin/backup-system-info.sh` | Saves package lists and configuration |
| `bin/kill-tracker.sh` | Kills GNOME Tracker indexer |
| `~/.config/systemd/user/kill-tracker.*` | Systemd units for periodic tracker cleanup |

---

## References

- [CACHEDIR.TAG Specification](https://bford.info/cachedir/)
- [GNOME Tracker Documentation](https://wiki.gnome.org/Projects/Tracker)
- [Kopia Documentation](https://kopia.io/docs/)
