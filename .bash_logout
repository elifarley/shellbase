# ~/.bash_logout: executed by bash(1) when login shell exits.

# when leaving the console clear the screen to increase privacy
if [ "$SHLVL" = 1 ]; then
  [ -x /usr/bin/clear_console ] && /usr/bin/clear_console -q
fi

# DDE (Docker Development Environment) support
# See https://github.com/elifarley/docker-rails/commit/5c1b77f8ce13c51f8dd4806c4f362a40a0b3f829
DDE_VIMINFO=~/.vim/viminfo/"$(hostname -s)"
test -f ~/.viminfo -a -d "$(dirname "$DDE_VIMINFO")" && cat ~/.viminfo > "$DDE_VIMINFO"
