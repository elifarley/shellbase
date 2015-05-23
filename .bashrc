# If not running interactively, don't do anyting
[[ $- != *i* ]] && return

test -f ~/.bash_private.gpg && \
  eval "$(gpg --decrypt ~/.bash_private.gpg 2>/dev/null)"

# smart advanced completion, download from
# http://bash-completion.alioth.debian.org/
test -f ~/local/bin/bash_completion && \
  . ~/local/bin/bash_completion

pss() { ps -o pid,user,c,start,args -C "$1" --cols 2000 ;}
alias p="ps aux |grep -i "
alias h="history|grep -i "
alias f="find . |grep -i "

# Puts the newest file at the bottom, right above the prompt
# l=long : h=human readable sizes : a=all : r=reverse sort : t=time sort : F=append indicator (one of */=>@|)
alias lt='ls --color=auto -lhFart'

alias ls='ls --color=auto -F'
alias dir='dir --color=auto'

# Download solarized color scheme from
# https://github.com/seebi/dircolors-solarized
# https://raw.githubusercontent.com/seebi/dircolors-solarized/master/dircolors.ansi-dark
eval $(dircolors -b ~/.dir_colors)

# define color to additional file types
export LS_COLORS=$LS_COLORS:"*.wmv=01;35":"*.wma=01;35":"*.flv=01;35":"*.m4a=01;35"

export GREP_OPTIONS='--color=auto'

# ignore case, long prompt, exit if it fits on one screen, allow colors for ls and grep colors
alias less='less -iMFSRX'

# Default colors for less
# From https://linuxtidbits.wordpress.com/2009/03/23/less-colors-for-man-pages/
# Based on Arch and Gentoo colors; good for Solarized dark theme
export LESS_TERMCAP_mb=$'\E[01;31m'       # begin blinking
export LESS_TERMCAP_md=$'\E[01;38;5;74m'  # begin bold
export LESS_TERMCAP_me=$'\E[0m'           # end mode
export LESS_TERMCAP_se=$'\E[0m'           # end standout-mode
export LESS_TERMCAP_so=$'\E[38;5;246m'    # begin standout-mode - info box
export LESS_TERMCAP_ue=$'\E[0m'           # end underline
export LESS_TERMCAP_us=$'\E[04;38;5;146m' # begin underline

# A different set of colors for manpages in less
# See http://www.cyberciti.biz/faq/linux-unix-colored-man-pages-with-less-command/
man() { env \
  LESS_TERMCAP_mb=$(printf "\e[1;31m") \
  LESS_TERMCAP_md=$(printf "\e[1;31m") \
  LESS_TERMCAP_me=$(printf "\e[0m") \
  LESS_TERMCAP_se=$(printf "\e[0m") \
  LESS_TERMCAP_so=$(printf "\e[1;44;33m") \
  LESS_TERMCAP_ue=$(printf "\e[0m") \
  LESS_TERMCAP_us=$(printf "\e[1;32m") \
    man "$@"
}

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
# Ignore duplicates, ls without options and builtin commands
HISTCONTROL=ignoredups
# commands with leading space do not get added to history
HISTCONTROL=ignorespace

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
