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
