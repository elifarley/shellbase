# 11-functions.sh: Core utility functions
# path_prepend: Safe PATH manipulation
# lsofwrite: Filter lsof output for writable files
# memstat: Memory statistics including zram/zswap
# s: sudo or sudo last command
# mvln: Move and create relative symlink
# cd_func: Directory history with pushd/popd

# Prepend a path to PATH env var only if it's not already there
# Usage: path_prepend /some/new/path
path_prepend() {
  local dir="$1"
  case ":$PATH:" in
    *":$dir:"*) ;;  # already present
    *) test -d "$dir" && export PATH="$dir${PATH:+:$PATH}" ;;
  esac
}

# Example: export lsof.write; watch 'lsof.write -c chromium -r5'
lsof.write()  {
  lsof "$@" | grep -E 'REG|DIR' | grep -Pv 'mem |^[^\s]+\s+\d+\s+[^\s]+\s+\d+r'
}

lsof.portshort() {
  local port="$1"; shift
  lsof -ti :"$port" "$@" | xargs -r ps -o pid,ppid,user=UID,cmd -p
}

lsof.port() {
  local port="$1"; shift
  lsof -ti :"$port" "$@" | xargs -r ps -o pid,ppid,user=UID,stime,c,time,stat,cmd -p
}

memstat() {
  vmstat -SM -s | grep -E -iv 'cpu|fork|boot|interrupts'
  vmstat -SM --wide
  echo '-------------------------------------------------------------------------------------------------------------'
  free -m
  echo '-------------------------------------------------------------------------------------------------------------'
  swapon --show=NAME,TYPE,LABEL,PRIO,SIZE,USED
  zramctl 2>/dev/null
  echo '-------------------------------------------------------------------------------------------------------------'

  ( cd /sys/kernel/debug/zswap 2>/dev/null || { echo "Root access needed to show ZSWAP info"; return 1 ;}
  test "$(cat pool_total_size)" -a "$(cat pool_total_size)" != '0' && {
    echo "ZSWAP written_back_pages $(cat written_back_pages)"
    echo "ZSWAP Used \
$(expr $(cat pool_total_size) / 1048576) MB \
($(expr $(cat stored_pages) \* 4096 / 1048576) MB uncompressed) \
= $(awk "BEGIN {print $(cat stored_pages) * 4096 / $(cat pool_total_size)}") x"
  })
  ( cd /sys/module/zswap/parameters && grep -R . )
}

s() { # do sudo, or sudo the last command if no argument given
  if [[ $# == 0 ]]; then
    sudo $(history -p '!!')
  else
    sudo "$@"
  fi
}

mvln() {
  test $# -ne 2 && echo "\
$(basename "$0") - Moves a file or dir to <TARGET> and creates a relative symlink in its original place
Usage: $0 <SRC> <TARGET>\
" && return 1
  local src="$1"; shift
  local target="$1"; shift
  local custom_target_name=1; test -e "$target" && custom_target_name=''
  mv -iv "$src" "$target"
  local basesrc="$(basename "$src")" dirsrc="$(dirname "$src")"
  local basetarget="$basesrc"
  test "$custom_target_name" &&  basetarget="$(basename "$target")" && target="$(dirname "$target")"
  local relpath="$(realpath --relative-to "$dirsrc" "$target")"
  ln -sv "$relpath/$basetarget" "$src"
}

# cd_func: Directory history with pushd/popd
# This function defines a 'cd' replacement function capable of keeping,
# displaying and accessing history of visited directories, up to 10 entries.
# To use: cd -- shows directory stack
# acd_func 1.0.5, 10-nov-2004
# Petar Marinov, http:/geocities.com/h2428, this is public domain
cd_func ()
 {
   local x2 the_new_dir adir index
   local -i cnt

   if [[ $1 ==  "--" ]]; then
     dirs -v
     return 0
   fi

   the_new_dir=$1
   [[ -z $1 ]] && the_new_dir=$HOME

   if [[ ${the_new_dir:0:1} == '-' ]]; then
     #
     # Extract dir N from dirs
     index=${the_new_dir:1}
     [[ -z $index ]] && index=1
     adir=$(dirs +$index)
     [[ -z $adir ]] && return 1
     the_new_dir=$adir
   fi

   #
   # '~' has to be substituted by ${HOME}
   [[ ${the_new_dir:0:1} == '~' ]] && the_new_dir="${HOME}${the_new_dir:1}"

   #
   # Now change to the new dir and add to the top of the stack
   pushd "${the_new_dir}" > /dev/null
   [[ $? -ne 0 ]] && return 1
   the_new_dir=$(pwd)

   #
   # Trim down everything beyond 11th entry
   popd -n +11 2>/dev/null 1>/dev/null

   #
   # Remove any other occurence of this dir, skipping the top of the stack
   for ((cnt=1; cnt <= 10; cnt++)); do
     x2=$(dirs +${cnt} 2>/dev/null)
     [[ $? -ne 0 ]] && return 0
     [[ ${x2:0:1} == '~' ]] && x2="${HOME}${x2:1}"
     if [[ "${x2}" == "${the_new_dir}" ]]; then
       popd -n +$cnt 2>/dev/null 1>/dev/null
       cnt=cnt-1
     fi
   done

   return 0
}
alias cd=cd_func
