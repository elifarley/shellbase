pss() { ps -o pid,user,c,start,args -C "$1" --cols 2000 ;}

# This will only use less if the output is bigger than the screen.
alias less='less -FSRX'

# Puts the newest file at the bottom, right above the prompt
# l=long : h=human readable sizes : a=all : r=reverse sort : t=time sort
alias lt='ls -lhart'
 
