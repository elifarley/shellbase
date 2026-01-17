# 00-main.sh: Core shell configuration
# Shell options: set -o vi, shopt settings
# Completion: Tab completion configuration
# History: HISTSIZE, HISTCONTROL, etc.
# Prompt: set_prompt function with PROMPT_COMMAND

# Umask
#
# /etc/profile sets 022, removing write perms to group + others.
# Set a more restrictive umask: i.e. no exec perms for others:
# umask 027
# Paranoid: neither group nor others have any perms:
# umask 077

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
# Note: ignoreboth = ignoredups + ignorespace. The ignorespace setting causes kitty terminal
# to show "showing running command will not be robust" warnings. This is harmless - it just
# means kitty's shell integration can't display the currently running command as reliably.
# To eliminate the warning, replace 'ignoreboth' with 'ignoredups' (but then commands with
# leading spaces WILL be saved to history).
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

#########

# See http://serverfault.com/questions/226783/how-to-tell-gnu-screen-to-run-bash-profile-in-each-new-window
# Use 'shell -$SHELL' in ~/.screenrc to make screen load ~/.bash_profile

# See http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/

# See http://serverfault.com/questions/226783/how-to-tell-gnu-screen-to-run-bash-profile-in-each-new-window
# Use 'shell -$SHELL' in ~/.screenrc to make screen load ~/.bash_profile

set_prompt () {
  LastStatus=$? # Must come first!

  ORANGE='\[\e[38;5;196m\]'
  BRED='\[\e[1;31m\]'
  RED='\[\e[0;31m\]'
  Red='\[\e[01;31m\]'
  BGREEN='\[\e[01;32m\]'
  GREEN='\[\e[0;32m\]'
  BBLUE='\[\e[1;34m\]'
  BLUE='\[\e[0;34m\]'
  Blue='\[\e[01;34m\]'
  DarkBlue='\[\e[01;32m\]'
  WHITE='\[\e[01;37m\]'
  NORMAL='\[\e[00m\]'
  BBLACK='\[\e[0;90m\]'

  FancyX='\342\234\227'
  Checkmark='\342\234\223'

  PS1="\n"

  [[ $LastStatus == 0 ]] && \
    PS1+="$GREEN$Checkmark" || \
    PS1+="$RED$FancyX$LastStatus"

  # Job count
  PS1+=" ${GREEN}\j"

  # If root, just print the host in red. Otherwise, print the current user
  # and host.
  [[ $EUID == 0 ]] && \
    PS1+=" ${RED}@\h" || \
    PS1+=" ${BLUE}\u${BBLACK}@${Blue}\h"

  # HH:MM and history index
  PS1+=" ${GREEN}\A ${BLUE}#\!"

  # [$PWD] with newline
  PS1+=" ${Blue}[${BGREEN}\w${Blue}]\n"

  # Set GNU Screen's window title
  #PS1+="\[\ek${HOSTNAME%%.*}\e\\\\\]"

  PS1+="${Red}\$${NORMAL} "

}; PROMPT_COMMAND='set_prompt'

