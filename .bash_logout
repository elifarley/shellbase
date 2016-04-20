# ~/.bash_logout: executed by bash(1) when login shell exits.

# when leaving the console clear the screen to increase privacy
if [ "$SHLVL" = 1 ]; then
  [ -x /usr/bin/clear_console ] && /usr/bin/clear_console -q
fi

# DDE (Docker Development Environment) support
DDE_VIMINFO=~/.vim/viminfo/"$(hostname -s)"
test -f ~/.viminfo -a -d "$(dirname "$DDE_VIMINFO")" && cat ~/.viminfo > "$DDE_VIMINFO"
