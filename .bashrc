# .bashrc: Interactive shell configuration
# Aliases and functions: Need these in every shell
# Prompt customization: Visual appearance
# Shell options: set -o vi, shopt settings
# Completion: Tab completion configuration
# PATH modifications: Yes, this actually works fine here too!

# Source global definitions
test -r /etc/bashrc && . /etc/bashrc

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*.sh; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc
