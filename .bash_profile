# Prompt
BGREEN='\[\033[1;32m\]'
GREEN='\[\033[0;32m\]'
BRED='\[\033[1;31m\]'
RED='\[\033[0;31m\]'
BBLUE='\[\033[1;34m\]'
BLUE='\[\033[0;34m\]'
NORMAL='\[\033[00m\]'
PS1="${BLUE}(${RED}\w${BLUE}) ${NORMAL}\h ${RED}\$ ${NORMAL}"

export PS1="\n# \t #\! ?\$? \u@\[$(tput bold)\]\[$(tput sgr0)\]\033[38;5;15m\033[38;5;196m\h\[$(tput sgr0)\]\[$(tput sgr0)\]\033[38;5;15m\033[38;5;15m \[[\w\[]\n> "
