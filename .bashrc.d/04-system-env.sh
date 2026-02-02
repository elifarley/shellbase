# 04-system-env.sh: System environment configuration
# Loads shellbase system environment variables from:
# 1. ~/.shellbase-system.env (user override, not tracked)
# 2. $SHELLBASE_REPO_DIR/etc/default/shellbase (tracked template)
# 3. Computed defaults if neither exists

# Prevent double-loading
[ -n "$SHELLBASE_SYSTEM_ENV_LOADED" ] && return 0
export SHELLBASE_SYSTEM_ENV_LOADED=1

# Detect repository directory (works before vars are set)
_shellbase_detect_repo() {
  local repo_dir
  # Try $SHELLBASE_REPO_DIR if already set
  [ -n "$SHELLBASE_REPO_DIR" ] && echo "$SHELLBASE_REPO_DIR" && return 0

  # Try relative to $HOME
  repo_dir="$HOME/IdeaProjects/shellbase"
  [ -d "$repo_dir" ] && echo "$repo_dir" && return 0

  # Try current directory if in repo
  [ -f "$PWD/CLAUDE.md" ] && echo "$PWD" && return 0

  # Fallback: try to find via git
  git rev-parse --show-toplevel 2>/dev/null
}

SHELLBASE_REPO_DIR="$(_shellbase_detect_repo)"
export SHELLBASE_REPO_DIR

# Load user override if present
if [ -r "$HOME/.shellbase-system.env" ]; then
  . "$HOME/.shellbase-system.env"
elif [ -r "$SHELLBASE_REPO_DIR/etc/default/shellbase" ]; then
  # Load tracked template
  . "$SHELLBASE_REPO_DIR/etc/default/shellbase"
fi

# Set defaults for any variables not already set (after sourcing user/template)
export SHELLBASE_USER="${SHELLBASE_USER:-$(id -un)}"
export SHELLBASE_USER_HOME="${SHELLBASE_USER_HOME:-$HOME}"
export SHELLBASE_PROJECT_ROOT="${SHELLBASE_PROJECT_ROOT:-$HOME/IdeaProjects}"
export SHELLBASE_BIN_DIR="${SHELLBASE_BIN_DIR:-$HOME/bin}"
export SHELLBASE_CACHE_DIR="${SHELLBASE_CACHE_DIR:-$HOME/.cache}"
export SHELLBASE_CONFIG_DIR="${SHELLBASE_CONFIG_DIR:-$HOME/.config}"

# Validate critical variables
: "${SHELLBASE_USER:?ERROR: SHELLBASE_USER not set}"
: "${SHELLBASE_USER_HOME:?ERROR: SHELLBASE_USER_HOME not set}"

# Export derived variables (only if not already set)
export SHELLBASE_REPO_BIN_DIR="${SHELLBASE_REPO_BIN_DIR:-$SHELLBASE_REPO_DIR/bin}"
export SHELLBASE_BACKUP_DIR="${SHELLBASE_BACKUP_DIR:-$HOME/Documents/system-info}"

# Debug: Show loading source (disabled by default)
# [ -n "$SHELLBASE_DEBUG" ] && echo "[shellbase] System env loaded from: ${SHELLBASE_ENV_SOURCE:-computed}"
