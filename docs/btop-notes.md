# Btop++ Configuration Notes

This document explains the Btop++ terminal resource monitor configuration. Btop++ is a feature-rich terminal-based system monitor that shows CPU, memory, disks, network, and processes.

---

## Overview

Btop++ is a modern replacement for htop/top with:
- Beautiful, responsive UI with mouse support
- Customizable themes and box layouts
- Low CPU usage compared to Python-based bpytop
- Vim-style keybindings support

---

## Configuration File

**Location**: `.config/btop/btop.conf`

This configuration enables:
- **Vim keys**: `h,j,k,l` for directional control
- **Rounded corners**: Better visual appearance
- **Custom presets**: Different box layouts for different needs

---

## Key Settings

```bash
color_theme = "Default"
theme_background = True
truecolor = True
vim_keys = True
rounded_corners = True
presets = "cpu:1:default,proc:0:default cpu:0:default,mem:0:default,net:0:default cpu:0:block,net:0:tty"
```

### Presets Explained

Presets are different box layouts. Press `1`-`9` to switch:

| Preset | Layout | Use Case |
|--------|--------|----------|
| 1 | `cpu:1:default,proc:0:default` | CPU + Process list (sidebar) |
| 2 | `cpu:0:default,mem:0:default,net:0:default` | CPU + Memory + Network (3 rows) |
| 3 | `cpu:0:block,net:0:tty` | CPU + Network (minimal) |

**Format**: `box_name:position:graph_symbol`
- Position: `0` = standard, `1` = alternate
- Graph symbols: `default`, `braille`, `block`, `tty`

### Vim Keys

When `vim_keys = True`:
- `h` = left (help becomes `Shift+h`)
- `j` = down
- `k` = up
- `l` = right (kill becomes `Shift+k`)

This is essential for vim users who want consistent navigation.

### Truecolor

When `truecolor = True`:
- Uses 24-bit colors (millions of colors)
- Falls back to 256-color (6x6x6 cube) if terminal doesn't support it
- Recommended for modern terminals

---

## Installation

### From Package Manager

```bash
# Debian/Ubuntu
sudo apt install btop

# Fedora
sudo dnf install btop

# Arch
sudo pacman -S btop
```

### From Source

See [btop++ GitHub](https://github.com/aristocratos/btop)

---

## Setup on New System

### Copy Config

```bash
# Create directory
mkdir -p ~/.config/btop

# Copy from shellbase
cp /path/to/shellbase/.config/btop/btop.conf ~/.config/btop/
```

### Verify

```bash
# Launch btop
btop

# Check version
btop --version

# Test config (will show errors if invalid)
btop
```

---

## Usage

### Basic Navigation

| Key | Action |
|-----|--------|
| `q` / `Ctrl+c` | Quit |
| `1`-`9` | Switch preset |
| `ESC` | Close menu or go back |
| `Enter` | Select |
| `Space` | Toggle selection |

### Vim Mode (when enabled)

| Key | Action |
|-----|--------|
| `h` | Left |
| `j` | Down |
| `k` | Up |
| `l` | Right |
| `g` | Go to top |
| `G` | Go to bottom |

### Process Management

| Key | Action |
|-----|--------|
| `Tab` | Select next box |
| `Shift+k` | Kill selected process (vim mode) or `k` (normal mode) |
| `Shift+e` | Terminate selected process |
| `Shift+r` | Renice selected process |

### Sorting

| Key | Action |
|-----|--------|
| `Left`/`Right` | Change sort category |
| `Shift+i` | Invert sort order |

### Filtering

Type to filter processes by name. Press `ESC` to clear filter.

---

## Customization

### Change Theme

```bash
# Edit btop.conf
color_theme = "nord"  # or catppuccin, gruvbox, etc.
```

Available themes depend on installation. Themes are in:
- `/usr/share/btop/themes/` (system)
- `~/.config/btop/themes/` (user)

### Custom Presets

Add your own layout:

```bash
# Add to presets list (space-separated)
presets = "cpu:1:default,proc:0:default cpu:0:default,mem:0:default,net:0:default mycustom:cpu:0:default,mem:0:default"
```

Then switch to it with the appropriate number key.

### Create Custom Theme

1. Copy an existing theme:
```bash
mkdir -p ~/.config/btop/themes
cp /usr/share/btop/themes/Default.theme ~/.config/btop/themes/mytheme.theme
```

2. Edit colors in the theme file

3. Set in btop.conf:
```bash
color_theme = "mytheme"
```

---

## Performance

Btop++ is efficient, but you can tune further:

```bash
# Update interval in milliseconds
update_ms = 1000  # Default (1 second)

# Reduce for slower systems
update_ms = 2000  # 2 seconds

# Increase for real-time monitoring
update_ms = 500   # 0.5 seconds
```

---

## Troubleshooting

### Colors Look Wrong

**Issue**: Terminal doesn't support truecolor

**Fix**:
```bash
# Disable truecolor
truecolor = False
```

### Vim Keys Not Working

**Issue**: Conflicts with default keys

**Check**:
```bash
# Verify setting in config
grep vim_keys ~/.config/btop/btop.conf
```

Remember: `hjkl` replace arrow keys, `Shift+h` = help, `Shift+k` = kill

### High CPU Usage

**Issue**: Update interval too low

**Fix**:
```bash
# Increase update_ms
update_ms = 2000
```

### Boxes Not Showing

**Issue**: Graph symbol not supported by terminal

**Try**:
```bash
# Change graph symbol in presets
# From: cpu:0:braille
# To:   cpu:0:default
```

---

## Box Reference

### CPU Box

Shows:
- CPU usage per core
- Overall CPU percentage
- Frequency (if available)

### Memory Box

Shows:
- RAM usage
- Swap usage
- Memory breakdown (apps, buffers, cache)

### Disk Box

Shows:
- Read/write speeds
- IO usage per disk
- Total IO over time

### Network Box

Shows:
- Upload/download speeds
- Connection count
- Total transfer over time

### Process Box

Shows:
- Process list (sortable, filterable)
- Per-process CPU/memory usage
- Tree view (toggle with `t`)

---

## Alternatives

| Tool | Pros | Cons |
|------|------|------|
| **btop++** | Beautiful, feature-rich, fast | Not default on most systems |
| htop | Ubiquitous, stable | Older UI, less customization |
| bashtop | Python, easier to modify | Slower than btop++ |
| glances | Web UI, export options | Heavier, Python |
| gtop | Node-based, graphical | Requires Node.js |

---

## Integration with Shellbase

### Autostart

You can add btop to your shell session or run it via a keybinding.

### In tmux/screen

Add to your `.tmux.conf` or `.screenrc`:
```bash
# Keybinding to launch btop
bind-key B run-shell "btop"
```

### Monitoring Script

Create a script to log system stats:
```bash
#!/bin/bash
# Save btop stats to file
btop --utf-force > ~/btop-log.txt
```

---

## Related Files

| File | Purpose |
|------|---------|
| `.config/btop/btop.conf` | Main configuration |
| `.config/btop/themes/*` | Custom themes |
| `~/.local/share/btop/log/btop.log` | Log file |

---

## References

- [Btop++ GitHub](https://github.com/aristocratos/btop)
- [Btop++ Documentation](https://github.com/aristocratos/btop/wiki)
- [Available Themes](https://github.com/aristocratos/btop/tree/master/themes)
