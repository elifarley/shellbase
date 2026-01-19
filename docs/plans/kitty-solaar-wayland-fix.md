# Root Cause Analysis: Kitty Rules Not Working in Solaar

## Summary

**ROOT CAUSE:** Kitty is running as a **native Wayland application**, while thorium/idea/ksnip run via **XWayland** (X11 compatibility layer). Solaar's `Process` condition only works with X11 windows on Wayland systems.

## Evidence Gathered

### 1. Session Type
```bash
$ echo $XDG_SESSION_TYPE
wayland
```
**Finding:** System is running Wayland with XWayland support (DISPLAY=:0 is set).

### 2. XWayland Clients (xlsclients output)
```
thorium-browser  ✓ (XWayland client - Process rules WORK!)
idea             ✓ (XWayland client - Process rules WORK!)
kopia-ui         ✓ (XWayland client - Process rules WORK!)
gsd-xsettings     ✓ (XWayland)
ibus-x11         ✓ (XWayland)
gnome-shell      ✓ (XWayland)
```
**Finding:** kitty is NOT listed - it's running native Wayland!

### 3. Why Thorium Rules "Work"
User confirmed thorium rules work. This is because:
- Thorium runs via XWayland (visible in xlsclients)
- Solaar can detect X11 windows even on Wayland via XWayland
- Kitty runs native Wayland, which Solaar cannot detect

### 4. Solaar Documentation Quote
From [Solaar Rules Documentation](https://pwr-solaar.github.io/Solaar/rules/):

> **Rule processing only fully works under X11.** When running under Wayland with X11 libraries loaded some features will not be available. **Rule features known not to work under Wayland include process and mouse process conditions**, although on GNOME desktop under Wayland, you can use those with the Solaar Gnome extension installed.

**Note:** XWayland windows ARE detectable because they appear as X11 clients.

## Solution

**Force kitty to use X11 backend (via XWayland)** instead of native Wayland.

### Method: Add to kitty.conf
Add this line to `~/.config/kitty/kitty.conf`:

```bash
# Force X11 backend so Solaar Process rules work
linux_display_server x11
```

From [kitty.conf documentation](https://sw.kovidgoyal.net/kitty/conf/):
> **`linux_display_server`** - Choose between Wayland and X11 backends. By default, an appropriate backend based on the system state is chosen automatically. Set it to `x11` or `wayland` to force the choice. Changing this option by reloading the config is not supported.

### Implementation Steps
1. Edit `~/.config/kitty/kitty.conf`
2. Add `linux_display_server x11`
3. **Restart kitty completely** (config reload doesn't work for this setting)
4. Verify kitty appears in `xlsclients` output
5. Test Solaar kitty rules

## Recommended Solution: xremap (Native Wayland + Per-App Rules)

**xremap** is a key/mouse remapper for Linux that:
- ✅ Works natively on Wayland (no X11 dependency)
- ✅ Supports **per-application remapping** (unlike logiops/input-remapper)
- ✅ Supports mouse button to keyboard shortcut mapping
- ✅ YAML configuration file
- ✅ Written in Rust, actively maintained

### Why Not input-remapper on Wayland?
From [input-remapper discussion #20](https://github.com/sezanzeb/input-remapper/discussions/20):
> "getting the active window seems to work in X, but **not in wayland**"

The shell script solution only works on X11, not Wayland.

### Installation

```bash
# Install via cargo (Rust package manager)
cargo install xremap

# Or install system package (if available)
sudo apt install xremap
```

### Configuration File

Create `~/.config/xremap/config.yml`:

```yaml
keymap:
  - name: Kitty Smart Shift
    application:
      only: kitty  # matches kitty WM_CLASS
    remap:
      KEY_THUMB: [Ctrl_L, Shift_L, F4]  # Thumb button → Ctrl+Shift+F4

  - name: Thorium Smart Shift
    application:
      only: thorium-browser
    remap:
      KEY_THUMB: [Ctrl_L, w]  # Same button → Ctrl+W in thorium

  - name: Idea Smart Shift
    application:
      only: idea
    remap:
      KEY_THUMB: F4  # Same button → F4 in idea
```

### Finding Button Names

```bash
# List available input devices
xremap --device

# Monitor key/mouse events to find button codes
xremap --monitor
```

## Files Involved
- `/home/ecc/.config/solaar/rules.yaml` - **DO NOT MODIFY** - Keep all existing rules (thorium, idea, etc. work fine)
- `~/.config/xremap/config.yml` - New configuration file **only for kitty-specific rules**

## Implementation Steps

1. Install xremap:
   ```bash
   cargo install xremap
   # or check apt
   apt-cache search xremap
   ```

2. Create config directory:
   ```bash
   mkdir -p ~/.config/xremap
   ```

3. Create `~/.config/xremap/config.yml` with **only kitty rules**:
   ```yaml
   keymap:
     - name: Kitty Smart Shift
       application:
         only: kitty
       remap:
           # Find actual button code with xremap --monitor
           BTN_9: [Ctrl_L, Shift_L, F4]
   ```

4. Find the correct mouse button code:
   ```bash
   xremap --monitor
   # Press Smart Shift button to find its code
   ```

5. Start xremap as service:
   ```bash
   # Create systemd user unit for autostart
   ```

## Verification
1. Keep Solaar running (for thorium, idea, etc.)
2. Start xremap
3. Focus kitty window
4. Press Smart Shift button
5. Verify Ctrl+Shift+F4 is sent in kitty

## Sources
- [xremap GitHub Repository](https://github.com/xremap/xremap)
- [xremap Example Config](https://github.com/xremap/xremap/blob/master/example/config.yml)
- [input-remapper Wayland Limitation Discussion](https://github.com/sezanzeb/input-remapper/discussions/20)
