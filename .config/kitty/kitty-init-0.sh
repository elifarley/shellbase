#!/bin/env bash

echo "### Kitty session: $PWD"

cat <<'EOF'
# set colors dynamically:
# kitty_mod + <ESC>  : go to kitty shell
# set-colors -a -c .config/kitty/custom.conf

# Kitty cheatsheet (kitty_mod = <CTRL> + <SHIFT>)

## WINDOWS (splits inside a tab)
- <ENTER> : New
- N       : New OS Window
- W       : Close
- F12     : Close OTHER windows in tab
- L       : Layout
- R       : Resize


- <LEFT> | <RIGHT> : Navigation (cycle through windows)
- 1...0   : Go to window (Clockwise from TOP-LEFT)
- \       : Go to last used window (nth_window -1)

- [ | ]  : Move window
- P      : Move window to TOP
- ;      : Detach window to tab (Ask)

## TABS
- T  : New
- q  : Quit tab (close)
- <ALT> + T : Title change for TAB

- <CTRL + ALT + LEFT> | <CTRL + ALT + RIGHT> : Navigation
- <SHIFT + CTRL + TAB> | <CTRL + TAB>       : Navigation
- 1...9 : Go to N-th tab
- <only ALT> + \  : Select tab (`select_tab`)

- <only CTRL + ALT> + [ | ]      : Move tab
- <only CTRL> + \      : Go to last used tab (goto_tab -1)
- <only CTRL + ALT> + ; : Detach tab to OS Window (Ask)

## Sessions
- <only F12>         : Go to last used session
- <only ALT + F12> : Select session from ~/.config/kitty/*.kitty-session

## SCROLLBACK / NAVIGATION (main screen)
- Z | X                   : Previous / Next shell prompt (requires shell integration)
- <UP> | <DOWN>           : Scroll by LINE
- <PAGE UP> | <PAGE DOWN> : Scroll by PAGE
- <HOME> | <END>          : Scroll to TOP | BOTTOM
- H                       : Browse scrollback in pager (less)
- G                       : Browse last command output in pager (requires shell integration)
- /                       : Search scrollback within pager

## CLIPBOARD / TEXT
- C         : Copy to clipboard
- V         : Paste from clipboard
- S         : Paste from selection
- O         : Pass selection to program
- U         : Unicode input

## UI / CONFIG / MISC
- - / =       : Increase / Decrease font size
- <BACKSPACE> : Restore font size

- <ESC>       : Open kitty shell
- E           : Open URL / hints (pick a URL/text on screen, then open)
- <DEL>       : Reset the terminal
- F1          : Show kitty help/docs
- F2          : Edit kitty.conf
- F5          : Reload kitty.conf
- F6          : Debug kitty config
- F11         : Toggle fullscreen
- F10         : Toggle maximized

## BACKGROUND OPACITY (multi-key chords)
- A > M       : Increase opacity
- A > L       : Decrease opacity
- A > 1       : Fully opaque
- A > D       : Reset opacity

EOF

