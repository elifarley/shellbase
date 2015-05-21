# Prompt
BGREEN='\[\033[1;32m\]'
GREEN='\[\033[0;32m\]'
ORANGE='\[\033[38;5;196m\]'
BRED='\[\033[1;31m\]'
RED='\[\033[0;31m\]'
BBLUE='\[\033[1;34m\]'
BLUE='\[\033[0;34m\]'
NORMAL='\[\033[00m\]'

export PS1="\n${GREEN}# \t #\! ?\$? ${ORANGE}\u${GREEN}@${ORANGE}\h ${BLUE}[${GREEN}\w${BLUE}]\n${RED}\$${NORMAL} "
