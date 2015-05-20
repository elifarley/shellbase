pss() { ps -o pid,user,c,start,args -C "$1" --cols 2000 ;}
