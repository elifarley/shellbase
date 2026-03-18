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

- Rule works for some apps but not others — no errors, just silent mismatch.
- After installing the GNOME extension, `Process` names change because the
  data source switches from X11 WM_CLASS + psutil to GNOME's `get_wm_class()`.

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

## Finding the Correct `Process` Name

**This is the #1 source of broken rules.** The name you need is whatever
GNOME's `get_wm_class()` returns — NOT the binary name, NOT the `.desktop`
file name, NOT what `ps` shows.

### Recipe: Query the active window's WM_CLASS

```bash
# 1. Focus the target app, then within N seconds the query runs:
sleep 5 && gdbus call --session \
  --dest org.gnome.Shell \
  --object-path /io/github/pwr_solaar/solaar \
  --method io.github.pwr_solaar.solaar.ActiveWindow
```

### Real-world examples (case-sensitive!)

| App          | Binary / psutil name | GNOME `get_wm_class()` | Rule value     |
|--------------|---------------------|------------------------|----------------|
| Thorium      | `thorium`           | `Thorium-browser`      | `Thorium`      |
| Firefox      | `firefox`           | `firefox`              | `firefox`      |
| Kitty        | `kitty`             | `kitty`                | `kitty`        |
| IntelliJ     | `idea`              | (check with recipe)    | `jetbrains-idea` (typical) |

### Why the name differs between X11 and Wayland

On **X11**, Solaar's `Process.evaluate()` checks three values and matches if
*any* starts with the rule string:

```python
# x11_focus_prog() returns (wm_instance, wm_class, psutil_name)
# e.g., ('thorium-browser', 'Thorium-browser', 'thorium')
#   → "thorium" matches psutil_name ✓
```

On **Wayland** (via GNOME extension), it returns only one value:

```python
# gnome_dbus_focus_prog() returns (wm_class,)
# e.g., ('Thorium-browser',)
#   → "thorium" does NOT match (case-sensitive prefix) ✗
#   → "Thorium" matches ✓
```

**Always use the gdbus recipe above to get the exact name.** Don't guess
from the binary — the case and format are unpredictable across apps.

## Rule Design Patterns

### Use `Or` to consolidate same-action rules (DRY)

When multiple apps map the same button to the same key, use `Or` instead of
duplicating the entire rule per app:

```yaml
# BAD: duplicated Key + KeyPress for each app
- Rule:
  - Process: Thorium
  - Key: [Smart Shift, pressed]
  - KeyPress: [Control_L, w]
- Rule:
  - Process: ksnip
  - Key: [Smart Shift, pressed]
  - KeyPress: [Control_L, w]

# GOOD: single rule, adding an app = adding one line
- Rule:
  - Or:
    - Process: Thorium
    - Process: firefox
    - Process: geany
    - Process: ksnip
  - Key: [Smart Shift, pressed]
  - KeyPress: [Control_L, w]
```

### Fallback rules go last

Rules evaluate top-to-bottom within a YAML document. Place app-specific rules
first, generic fallbacks (like `Alt+F4` for any app) last. The first matching
rule wins.

### `Process` matching is a case-sensitive prefix

`Process` does a prefix match (`str.startswith`) against the value(s) returned
by the active window query. On Wayland this is a **single** WM_CLASS string;
on X11 it checks three strings (instance, class, psutil name).

Because it's case-sensitive, `Process: thorium` does NOT match `Thorium-browser`.
Always verify with the [gdbus recipe](#recipe-query-the-active-windows-wm_class) above.

## File Management

`rules.yaml` is symlinked from the shellbase repo:

```
~/.config/solaar/rules.yaml -> ~/IdeaProjects/shellbase/.config/solaar/rules.yaml
```

Edits in either location are the same file. The Solaar GUI can still read/write
through the symlink transparently.
