# Solaar Rules Configuration

Logitech device button/gesture remapping via [Solaar](https://github.com/pwr-Solaar/Solaar)'s rule engine.

> **Why a README instead of YAML comments?**
> Solaar's GUI rewrites `rules.yaml` on save, stripping all comments.
> This file preserves the knowledge that comments cannot.

## Wayland: The `Process` Condition Trap

**The `Process` condition does NOT work on native Wayland apps out of the box.**

Solaar's `Process` match calls `x11_focus_prog()` internally — it reads `WM_CLASS` via Xlib,
which only exists for X11/XWayland windows. Native Wayland apps are invisible to it.

### Symptoms

- Rule works for Thorium (runs under XWayland) but not Firefox (native Wayland).
- No errors in Solaar — the condition silently returns `False`.

### Diagnosis: Is an app X11 or Wayland?

```bash
# Lists only XWayland clients — if your app isn't here, it's native Wayland
xlsclients | grep -i <app-name>
```

### Fix: Solaar GNOME Extension

On GNOME desktops, install the [Solaar GNOME extension](https://extensions.gnome.org/extension/6162/solaar-extension/)
to expose focused-window info to Solaar via D-Bus:

```bash
# Verify installation
gnome-extensions info solaar-extension@sidevesh

# Must show State: ENABLED — a GNOME Shell restart (log out/in) is required after install
```

**Without this extension, every `Process` rule is dead code on Wayland.**

### Solaar version matters

Ubuntu/Pop!_OS repos ship ancient versions (1.1.1 in Jammy). The PPA
`ppa:solaar-unifying/stable` provides current releases (1.1.13+) with
improved Wayland awareness. Always use the PPA.

## Rule Design Patterns

### Use `Or` to consolidate same-action rules (DRY)

When multiple apps map the same button to the same key, use `Or` instead of
duplicating the entire rule per app:

```yaml
# BAD: duplicated Key + KeyPress for each app
- Rule:
  - Process: thorium
  - Key: [Smart Shift, pressed]
  - KeyPress: [Control_L, w]
- Rule:
  - Process: ksnip
  - Key: [Smart Shift, pressed]
  - KeyPress: [Control_L, w]

# GOOD: single rule, adding an app = adding one line
- Rule:
  - Or:
    - Process: thorium
    - Process: firefox
    - Process: ksnip
  - Key: [Smart Shift, pressed]
  - KeyPress: [Control_L, w]
```

### Fallback rules go last

Rules evaluate top-to-bottom within a YAML document. Place app-specific rules
first, generic fallbacks (like `Alt+F4` for any app) last. The first matching
rule wins.

### `Process` matching is a case-sensitive prefix

`Process: firefox` matches any window whose WM_CLASS *or* psutil process name
**starts with** `firefox` (case-sensitive). This means `firefox` matches
`firefox`, `firefox-bin`, `firefox-esr`, etc.

## File Management

`rules.yaml` is symlinked from the shellbase repo:

```
~/.config/solaar/rules.yaml -> ~/IdeaProjects/shellbase/.config/solaar/rules.yaml
```

Edits in either location are the same file. The Solaar GUI can still read/write
through the symlink transparently.
