test -f ~/.bash_private.gpg && \
  eval "$(gpg --decrypt ~/.bash_private.gpg 2>/dev/null)"

# smart advanced completion, download from
# http://bash-completion.alioth.debian.org/
test -f ~/local/bin/bash_completion && \
  . ~/local/bin/bash_completion

# Prompt
BGREEN='\[\033[1;32m\]'
GREEN='\[\033[0;32m\]'
BRED='\[\033[1;31m\]'
RED='\[\033[0;31m\]'
BBLUE='\[\033[1;34m\]'
BLUE='\[\033[0;34m\]'
NORMAL='\[\033[00m\]'
PS1="${BLUE}(${RED}\w${BLUE}) ${NORMAL}\h ${RED}\$ ${NORMAL}"

pss() { ps -o pid,user,c,start,args -C "$1" --cols 2000 ;}

psgrep() {
	if test ! -z "$1" ; then
		echo "Grepping for processes matching $1..."
		ps aux | grep -i "$1" | grep -v grep
	else
		echo "!! Need name to grep for"
	fi
}

# ignore case, long prompt, exit if it fits on one screen, allow colors for ls and grep colors
alias less='less -iMFSRX'

# Puts the newest file at the bottom, right above the prompt
# l=long : h=human readable sizes : a=all : r=reverse sort : t=time sort
alias lt='ls -lhart'
 
# Color for manpages in less makes manpages a little easier to read:
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

export GREP_OPTIONS='--color=auto'
 
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

prompt_command() {
    p=$PWD  # p is much easier to type in interactive shells
    # a special IFS should be limited to 1 liners or inside scripts.
    # Otherwise it only causes mistakes.
    unset IFS
}
PROMPT_COMMAND=prompt_command

test "$PS1" != "" -a "${STARTED_SCREEN:-x}" = x  -a "${SSH_TTY:-x}" != x && {
STARTED_SCREEN=1 ; export STARTED_SCREEN
[ -d $HOME/lib/screen-logs ] || mkdir -p $HOME/lib/screen-logs

sleep 1
screen -U -RR && exit 0

echo "Screen failed! continuing with normal bash startup"
}
