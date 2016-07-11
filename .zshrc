test -r ~/.shell-env && source ~/.shell-env
test -r ~/.shell-aliases && source ~/.shell-aliases

set -o vi

# See http://superuser.com/a/328137/32755
bindkey -M viins '^R' history-incremental-search-backward
bindkey -M vicmd '^R' history-incremental-search-backward
