# 10-aliases.sh: Basic shell aliases
# Core utilities: ps, history, find, screen, jobs
# ls aliases: lt, ll, ls, l, dir, vdir
# Safety aliases: rm, cp, mv (interactive mode)
# Colors: grep, egrep, fgrep

# Process and history aliases
alias pss='ps -o uname,pid,ppid,c,%cpu,cputime=CPU-time,%mem,rss,start,wchan,args --cols 2000 -C'
alias p='ps -fe |grep -i'
alias hs='history|grep -i'
alias f="find . -type d \(-name '.git' -o -name '.hg' \) -prune -o -print |grep -i"
alias sc='screen -DR'
alias j='\jobs -l'
alias fgg='\fg %'
alias bgg='\bg %'

# Directory listing aliases
# Puts the newest file at the bottom, right above the prompt
# l=long : h=human readable sizes : a=all : r=reverse sort : t=time sort : F=append indicator (one of */=>@|)
alias lt='\ls --color=auto -lhFArt'
alias ll='\ls --color=auto -lhFa'
alias ls='\ls --color=auto -lhFAG'
alias  l='\ls --color=auto -F --group-directories-first'
alias dir='\dir --color=auto'
alias vdir='\vdir --color=auto'

# Interactive safety aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Human-readable output
alias df='df -h'
alias du='du -h'

# Color output
alias whence='type -a'
alias grep='grep --color'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
