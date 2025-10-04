# .bashrc: Interactive shell configuration
# Aliases and functions: Need these in every shell
# Prompt customization: Visual appearance
# Shell options: set -o vi, shopt settings
# Completion: Tab completion configuration
# PATH modifications: Yes, this actually works fine here too!

# Source global definitions
test -r /etc/bashrc && . /etc/bashrc

# If not running interactively, don't do anything
[[ "$-" != *i* ]] && return

# Shell Options
#
# See man bash for more options...
#
# Don't wait for job termination notification
# set -o notify
#
# Don't use ^D to exit
# set -o ignoreeof
#
# Use case-insensitive filename globbing
# shopt -s nocaseglob
#
# When changing directory small typos can be ignored by bash
# for example, cd /vr/lgo/apaache would find /var/log/apache
shopt -s cdspell

# Completion options
#
# These completion tuning parameters change the default behavior of bash_completion:
#
# Define to access remotely checked-out files over passwordless ssh for CVS
# COMP_CVS_REMOTE=1
#
# Define to avoid stripping description in --option=description of './configure --help'
# COMP_CONFIGURE_HINTS=1
#
# Define to avoid flattening internal contents of tar files
# COMP_TAR_INTERNAL_PATHS=1
#
# Uncomment to turn on programmable completion enhancements.
# Any completions you add in ~/.bash_completion are sourced last.
# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
test -f /usr/share/bash-completion/bash_completion && . /usr/share/bash-completion/bash_completion
test -f /etc/bash_completion && . /etc/bash_completion
# smart advanced completion, download from
# http://bash-completion.alioth.debian.org/
test -f ~/local/bin/bash_completion && . ~/local/bin/bash_completion

# History Options
#
export HISTFILESIZE=20000
export HISTSIZE=10000

# Make bash append rather than overwrite the history on disk
shopt -s histappend

# Combine multiline commands into one in history
shopt -s cmdhist
# Ignore duplicates, ls without options, builtin commands and lines with leading spaces
HISTCONTROL=ignoreboth

export HISTIGNORE="&:ls:[bf]g:exit"
#
# Don't put duplicate lines in the history.
export HISTCONTROL=$HISTCONTROL${HISTCONTROL+,}ignoredups
#
# Ignore some controlling instructions
# HISTIGNORE is a colon-delimited list of patterns which should be excluded.
# The '&' is a special pattern which suppresses duplicate entries.
# export HISTIGNORE=$'[ \t]*:&:[fb]g:exit'
export HISTIGNORE=$'[ \t]*:&:[fb]g:exit:ls' # Ignore the ls command as well
#
# Whenever displaying the prompt, write the previous line to disk
# export PROMPT_COMMAND="history -a"

# Aliases
#
# Some people use a different file for aliases
# if [ -f "${HOME}/.bash_aliases" ]; then
#   source "${HOME}/.bash_aliases"
# fi
#

# Some example alias instructions
# If these are enabled they will be used instead of any instructions
# they may mask.  For example, alias rm='rm -i' will mask the rm
# application.  To override the alias instruction use a \ before, ie
# \rm will call the real rm not the alias.
#
# Interactive operation...
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
#
# Default to human readable figures
alias df='df -h'
alias du='du -h'
#
# Misc :)
# alias less='less -r'                          # raw control characters
alias whence='type -a'                        # where, of a sort
alias grep='grep --color'                     # show differences in colour
# alias egrep='egrep --color=auto'              # show differences in colour
alias fgrep='fgrep --color=auto'              # show differences in colour
#
# Some shortcuts for different directory listings
# alias ls='ls -hF --color=tty'                 # classify files in colour
alias dir='ls --color=auto --format=vertical'
alias vdir='ls --color=auto --format=long'
alias ll='ls -Falko'                              # long list
alias la='ls -A'                              # all but . and ..
alias l='ls -CF'                              #

# Umask
#
# /etc/profile sets 022, removing write perms to group + others.
# Set a more restrictive umask: i.e. no exec perms for others:
# umask 027
# Paranoid: neither group nor others have any perms:
# umask 077

# Functions
#
# Some people use a different file for functions
# if [ -f "${HOME}/.bash_functions" ]; then
#   source "${HOME}/.bash_functions"
# fi
#
# Some example functions:
#
# a) function settitle
# settitle () 
# { 
#   echo -ne "\e]2;$@\a\e]1;$@\a"; 
# }
# 
# b) function cd_func
# This function defines a 'cd' replacement function capable of keeping, 
# displaying and accessing history of visited directories, up to 10 entries.
# To use it, uncomment it, source this file and try 'cd --'.
# acd_func 1.0.5, 10-nov-2004
# Petar Marinov, http:/geocities.com/h2428, this is public domain
# cd_func ()
# {
#   local x2 the_new_dir adir index
#   local -i cnt
# 
#   if [[ $1 ==  "--" ]]; then
#     dirs -v
#     return 0
#   fi
# 
#   the_new_dir=$1
#   [[ -z $1 ]] && the_new_dir=$HOME
# 
#   if [[ ${the_new_dir:0:1} == '-' ]]; then
#     #
#     # Extract dir N from dirs
#     index=${the_new_dir:1}
#     [[ -z $index ]] && index=1
#     adir=$(dirs +$index)
#     [[ -z $adir ]] && return 1
#     the_new_dir=$adir
#   fi
# 
#   #
#   # '~' has to be substituted by ${HOME}
#   [[ ${the_new_dir:0:1} == '~' ]] && the_new_dir="${HOME}${the_new_dir:1}"
# 
#   #
#   # Now change to the new dir and add to the top of the stack
#   pushd "${the_new_dir}" > /dev/null
#   [[ $? -ne 0 ]] && return 1
#   the_new_dir=$(pwd)
# 
#   #
#   # Trim down everything beyond 11th entry
#   popd -n +11 2>/dev/null 1>/dev/null
# 
#   #
#   # Remove any other occurence of this dir, skipping the top of the stack
#   for ((cnt=1; cnt <= 10; cnt++)); do
#     x2=$(dirs +${cnt} 2>/dev/null)
#     [[ $? -ne 0 ]] && return 0
#     [[ ${x2:0:1} == '~' ]] && x2="${HOME}${x2:1}"
#     if [[ "${x2}" == "${the_new_dir}" ]]; then
#       popd -n +$cnt 2>/dev/null 1>/dev/null
#       cnt=cnt-1
#     fi
#   done
# 
#   return 0
# }
# 
# alias cd=cd_func

#########

# vi editing mode. Use it if you prefer vim over Emacs
# See http://www.catonmat.net/download/bash-vi-editing-mode-cheat-sheet.txt
set -o vi
# http://unix.stackexchange.com/questions/104094/is-there-any-way-to-enable-ctrll-to-clear-screen-when-set-o-vi-is-set
bind -m vi-insert "\C-l":clear-screen

bind -m vi-insert '\C-a':beginning-of-line
bind -m vi-insert '\C-e':end-of-line

# Use `bind -P` to list current bindings


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

#use extra globing features. See man bash, search extglob.
shopt -s extglob
#include .files when globbing.
shopt -s dotglob
#When a glob expands to nothing, make it an empty string instead of the literal characters.
shopt -s nullglob

# Set MANPATH so it includes users' private man if it exists
if [ -d "${HOME}/man" ]; then
  MANPATH="${HOME}/man:${MANPATH}"
fi

# Set INFOPATH so it includes users' private info if it exists
if [ -d "${HOME}/info" ]; then
  INFOPATH="${HOME}/info:${INFOPATH}"
fi

# User specific environment and startup programs

# See http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/

# See http://serverfault.com/questions/226783/how-to-tell-gnu-screen-to-run-bash-profile-in-each-new-window
# Use 'shell -$SHELL' in ~/.screenrc to make screen load ~/.bash_profile

set_prompt () {
  LastStatus=$? # Must come first!

  ORANGE='\[\e[38;5;196m\]'
  BRED='\[\e[1;31m\]'
  RED='\[\e[0;31m\]'
  Red='\[\e[01;31m\]'
  BGREEN='\[\e[1;32m\]'
  GREEN='\[\e[0;32m\]'
  BBLUE='\[\e[1;34m\]'
  BLUE='\[\e[0;34m\]'
  Blue='\[\e[01;34m\]'
  DarkBlue='\[\e[01;32m\]'
  WHITE='\[\e[01;37m\]'
  NORMAL='\[\e[00m\]'

  FancyX='\342\234\227'
  Checkmark='\342\234\223'

  PS1="\n"

  [[ $LastStatus == 0 ]] && \
    PS1+="$GREEN$Checkmark" || \
    PS1+="$RED$FancyX$LastStatus"

  # Job count
  PS1+=" ${Blue}\j"

  # If root, just print the host in red. Otherwise, print the current user
  # and host.
  [[ $EUID == 0 ]] && \
    PS1+=" ${RED}@\h" || \
    PS1+=" ${BLUE}\u${DarkBlue}@${Blue}\h"

  # HH:MM and history index
  PS1+=" ${GREEN}\A #\!"

  # [$PWD] with newline
  PS1+=" ${Blue}[${DarkBlue}\w${Blue}]\n"

  # Set GNU Screen's window title
  #PS1+="\[\ek${HOSTNAME%%.*}\e\\\\\]"

  PS1+="${Red}\$${NORMAL} "

}; PROMPT_COMMAND='set_prompt'

test -r ~/.shell-aliases && . ~/.shell-aliases
test -r ~/.shell-env && . ~/.shell-env
test -r ~/.env && . ~/.env # Secret keys
test -f ~/.bash_private.gpg && \
  eval "$(gpg --decrypt ~/.bash_private.gpg 2>/dev/null)"

# Set PATH so it includes user's private bin if it exists
prepend_to_path "$HOME"/bin

# Start ssh-agent if not running and SSH_AUTH_SOCK is not set
if [ -z "$SSH_AUTH_SOCK" ]; then
    # Check if agent is already running
    if [ -f ~/.ssh-agent-env ]; then
        . ~/.ssh-agent-env > /dev/null
    fi
    # Verify agent is responsive
    if ! ssh-add -l &>/dev/null; then
        eval $(ssh-agent) > ~/.ssh-agent-env
        ssh-add ~/.ssh/id_ed25519
    fi
fi

# Activate Python in user's venv
test -r ~/.venv/bin/activate && . ~/.venv/bin/activate

# Local-only config
test -r ~/.shell-local-conf && . ~/.shell-local-conf

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
