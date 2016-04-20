
# DDE (Docker Development Environment) support
DDE_VIMINFO=~/.vim/viminfo/"$(hostname -s)"
test -f ~/.viminfo -a -d "$(dirname "$DDE_VIMINFO")" && cat ~/.viminfo > "$DDE_VIMINFO"
