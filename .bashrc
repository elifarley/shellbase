pss() { ps -o pid,user,c,start,args -C "$1" --cols 2000 ;}

# This will only use less if the output is bigger than the screen.
alias less='less -FSRX'

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
