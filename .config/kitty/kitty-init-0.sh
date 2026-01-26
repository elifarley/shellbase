echo "### Kitty session: $PWD"

cat <<'EOF'
# Kitty cheatsheet (kitty_mod = <CTRL> + <SHIFT>)

1) WINDOWS (splits inside a tab)
- <ENTER> : New
- N       : New OS Window
- W       : Close
- F12     : Close OTHER windows in tab
- L       : Layout
- R       : Resize


- [ | ] : Navigation
- 1...0 : Go to window (Clockwise from TOP-LEFT)
- \     : Go to last used window (nth_window -1)

- F | B  : Move window Forward | Backward
- P      : Move window to TOP
- <only CTRL> + `   : Detach window to tab (Ask)

2) TABS
- T  : New
- q  : Quit tab (close)
- <ALT> + T : Title change for TAB

- <LEFT> | <RIGHT>: Navigation
- <SHIFT + CTRL + TAB> | <CTRL + TAB>: Navigation
- 1...9 : Go to N-th tab

- < | >           : Move tab
- <only CTRL> + \      : Go to last used tab (goto_tab -1)
- ` : Detach tab to OS Window (Ask)


3) SCROLLBACK / NAVIGATION (main screen)
- Z | X                   : Previous / Next shell prompt (requires shell integration)
- <UP> | <DOWN>           : Scroll by LINE
- <PAGE UP> | <PAGE DOWN> : Scroll by PAGE
- <HOME> | <END>          : Scroll to TOP | BOTTOM
- H                       : Browse scrollback in pager (less)
- G                       : Browse last command output in pager (requires shell integration)
- /                       : Search scrollback within pager

4) CLIPBOARD / TEXT
- C         : Copy to clipboard
- V         : Paste from clipboard
- S         : Paste from selection
- O         : Pass selection to program
- U         : Unicode input

5) UI / CONFIG / MISC
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

6) BACKGROUND OPACITY (multi-key chords)
- A > M       : Increase opacity
- A > L       : Decrease opacity
- A > 1       : Fully opaque
- A > D       : Reset opacity

EOF

