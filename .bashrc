# .bashrc

# Source global definitions
test -r /etc/bashrc && . /etc/bashrc

# If not running interactively, don't do anyting
[[ $- != *i* ]] && return

test -r ~/.shell-aliases && . ~/.shell-aliases
test -r ~/.shell-env && . ~/.shell-env

# User specific aliases and functions

test -f ~/.bash_private.gpg && \
  eval "$(gpg --decrypt ~/.bash_private.gpg 2>/dev/null)"

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
test -f /usr/share/bash-completion/bash_completion && . /usr/share/bash-completion/bash_completion
test -f /etc/bash_completion && . /etc/bash_completion
# smart advanced completion, download from
# http://bash-completion.alioth.debian.org/
test -f ~/local/bin/bash_completion && . ~/local/bin/bash_completion

# http://unix.stackexchange.com/questions/72086/ctrl-s-hang-terminal-emulator
# See "The TTY demystified" - http://linusakesson.net/programming/tty/index.php
# http://catern.com/posts/terminal_quirks.html
# So as not to be disturbed by Ctrl-S ctrl-Q in terminals:
stty -ixon

# http://stackoverflow.com/questions/21806168/vim-use-ctrl-q-for-visual-block-mode-in-vim-gnome
# Allow <CTRL>-Q to be sent to terminal apps
stty start undef

# Bash won't get SIGWINCH if another process is in the foreground.
# Enable checkwinsize so that bash will check the terminal size when
# it regains control.  #65623
# http://cnswww.cns.cwru.edu/~chet/bash/FAQ (E11)
shopt -s checkwinsize

export HISTFILESIZE=20000
export HISTSIZE=10000
shopt -s histappend
# Combine multiline commands into one in history
shopt -s cmdhist
# Ignore duplicates, ls without options, builtin commands and lines with leading spaces
HISTCONTROL=ignoreboth

export HISTIGNORE="&:ls:[bf]g:exit"

#use extra globing features. See man bash, search extglob.
shopt -s extglob
#include .files when globbing.
shopt -s dotglob
#When a glob expands to nothing, make it an empty string instead of the literal characters.
shopt -s nullglob
# fix spelling errors for cd, only in interactive shell
shopt -s cdspell

# vi editing mode. Use it if you prefer vim over Emacs
# See http://www.catonmat.net/download/bash-vi-editing-mode-cheat-sheet.txt
set -o vi
# http://unix.stackexchange.com/questions/104094/is-there-any-way-to-enable-ctrll-to-clear-screen-when-set-o-vi-is-set
bind -m vi-insert "\C-l":clear-screen

s() { # do sudo, or sudo the last command if no argument given
  if [[ $# == 0 ]]; then
    sudo $(history -p '!!')
  else
    sudo "$@"
  fi
}

