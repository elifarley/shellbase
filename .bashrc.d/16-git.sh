# 16-git.sh: Git functions and aliases
# Uses Hug (Humane Git) - see ~/IdeaProjects/hug-scm
# Aliases: g (hug), oco (opencommit), git.verbose
# Functions: git.rename, git.grep, git.hlog

alias g=hug

# See https://github.com/marketplace/actions/opencommit-improve-commits-with-ai
alias oco='hug ss && oco'
alias ocoa='hug a && oco'
alias ocob='hug back && oco'

# See convo about the Hug tool at https://poe.com/chat/vwu52ea0bup1zllwyg
alias git.verbose='GIT_TRACE=1 GIT_SSH_COMMAND="ssh -v" git'

# ssh-add -l
# GIT_SSH_COMMAND="ssh -i ~/.ssh/your_private_key -o IdentitiesOnly=yes" git push
# git branch -a --contains 8beeff00d
# git show 8beeff00d

# git.squash
# git commit --edit -m"$(git log --format=%B --reverse HEAD..HEAD@{1})"

# Rename branch locally and remotely
git.rename() (
  currentBranch="$(git rev-parse --abbrev-ref HEAD)"
  test $# != 1 && cat <<EOF && return 1
  Renames the current branch ($currentBranch) both locally and remotely.
  USAGE:
  git rename <new branch name>
EOF

  newBranch="$1"; shift
  git branch -m "$newBranch" && \
  git push origin :"$currentBranch" "$newBranch"
)

# Search git history for code changes
git.grep() {
  local search_string="$1"; shift
  local file_path="$1"
  local files=()

  test "$file_path" &&
    files+=("--" "$file_path")

  #git grep -B 1 "$search_string" $(git branch -l | grep -v '^\*' | awk '{print $1}') "${files[@]}"
  git log --all --oneline  --graph -G"$search_string" "${files[@]}"
  echo ' Then...
# git branch -a --contains <commit hash>
# git show <commit hash>
'
}

# Human-readable git log with Base58 timestamps
git.hlog() (
  # Order-Preserving Base58 (OPB58)
  # Omit IOlo
  BASE58=$(echo {0..9} {A..H} {J..N} {P..Z} {a..k} {m..n} {p..z} | tr -d ' ')
  int2b58() {
    local i n="$1" sign
    ((n < 0 )) && printf -- '-' && n=$((-n))
    for i in $(echo "obase=58; $n" | bc); do
      printf ${BASE58:$(( 10#$i )):1}
    done; echo
  }

  hex2decimal() { printf '%u' "0x$1"; echo ;}

  hfrev() {
    # $(date -d 2023-01-01 +%s) = 1672527600
    # 1672527600/60 = 27875460
    local ts="$1" author="$2" pr="$3" \
    hfrevTS=$(( ts / 60 - 27875460 ))
    # echo "$ts $author [$pr] $msg"
    # 58 ** 2 = 3364
    authorHash=$((
      $(hex2decimal $(echo "$author" | md5sum | head -c3))
      % 3364
    ))
    printf '%4s.%2s.%04d\n' \
      "$(int2b58 $hfrevTS)" \
      "$(int2b58 $authorHash )" \
      "$pr" \
      | tr ' ' '0'
  }

  while read rev ts author msg; do
    pr="$(echo "$msg" | sed -En 's/.*\(#([0-9]+)\)$/\1/p')"
    git log -1 --format="$(hfrev "$ts" "$author" "$pr") %an %s" \
      "$rev"
  done < <(git log --format='%H %at %an:%ae %s' "$@")
)
