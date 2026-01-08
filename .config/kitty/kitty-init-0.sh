cat <<EOF
# Kitty cheatsheet (kitty_mod = <CTRL> + <SHIFT>)

1) WINDOWS (splits inside a tab)
- <ENTER>   : New
- `Q`       : Close
- `[` | `]` : Navigation
- `F` | `B` : Move window Forward | Backward
- `1`...`0` : Focus window (Clockwise from TOP-LEFT)
-     `     : Move window to TOP
- `L`       : Layout
- `N`       : New OS Window
- `R`       : Resize

2) TABS
- `T`  : New
- `Q`  : Close
- <LEFT> | <RIGHT>: Navigation
- `<` | `>` : Move tab
- <ALT> + `T` : Title change for TAB

3) SCROLLBACK / NAVIGATION (main screen)
- <UP> | <DOWN>             : Scroll by LINE
- <PAGE UP> | <PAGE DOWN>   : Scroll by PAGE
- <HOME> | <END>            : Scroll to TOP | BOTTOM
- `Z` | `X`                 : Previous / Next shell prompt (requires shell integration)
- `H`                       : Browse scrollback in pager (less)
- `G`                       : Browse last command output in pager (requires shell integration)
- `/`                       : Search scrollback within pager

4) CLIPBOARD / TEXT
- `C`         : Copy to clipboard
- `V`         : Paste from clipboard
- `S`         : Paste from selection
- `O`         : Pass selection to program
- `U`         : Unicode input

5) UI / CONFIG / MISC
- `=` / `-`   : Increase / Decrease font size
- <BACKSPACE> : Restore font size
- <ESC>       : Open kitty shell
- `E`         : Open URL / hints (pick a URL/text on screen, then open)
- <DEL>       : Reset the terminal
- F1          : Show kitty help/docs
- F2          : Edit kitty.conf
- F5          : Reload kitty.conf
- F6          : Debug kitty config
- F11         : Toggle fullscreen
- F10         : Toggle maximized

6) BACKGROUND OPACITY (multi-key chords)
- A > M       : Increase opacity
- A > L       : Decrease opacity
- A > 1       : Fully opaque
- A > D       : Reset opacity

EOF

