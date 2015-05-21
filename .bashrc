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

# ignore case, long prompt, exit if it fits on one screen, allow colors for ls and grep colors
alias less='less -iMFSRX'

# Puts the newest file at the bottom, right above the prompt
# l=long : h=human readable sizes : a=all : r=reverse sort : t=time sort : F=append indicator (one of */=>@|)
alias lt='ls --color=auto -lhFart'

alias ls='ls --color=auto -F'
alias dir='dir --color=auto'

# Color for manpages in less makes manpages a little easier to read:
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

export GREP_OPTIONS='--color=auto'

# define color to additional file types
export LS_COLORS=$LS_COLORS:"*.wmv=01;35":"*.wma=01;35":"*.flv=01;35":"*.m4a=01;35"

# Download solarized color scheme from
# https://github.com/seebi/dircolors-solarized
# https://raw.githubusercontent.com/seebi/dircolors-solarized/master/dircolors.ansi-dark
eval $(dircolors -b ~/.dir_colors)

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
# vi mode
set -o vi

s() { # do sudo, or sudo the last command if no argument given
    if [[ $# == 0 ]]; then
    	sudo $(history -p '!!')
    else
    	sudo "$@"
    fi
}
