# 19-apps.sh: Application-specific aliases and functions
# jq: jqlog for parsing JSON logs
# kopia: Backup tool alias
# ssh: kitty kitten ssh integration
# claude: Multiple Claude Code configuration aliases

# jq

# Parse JSON logs from stdin
jqlog() {
  grep --line-buffered -E '^{' | while read -r LINE; do echo -E "$LINE" \
    | jq -r '.level + " " + .loggerName + "\t" + .message'; done
}

# Application aliases

# Add kitty installed via official installer to PATH
path_prepend "$HOME/.local/kitty.app/bin"

# kitty: Display effective configuration from running kitty process
kitty.effective-config() {
  local KITTY_PID=${1:-$(pgrep -x kitty | head -1)}

  if [ -z "$KITTY_PID" ]; then
    echo "Error: No kitty process found" >&2
    return 1
  fi

  local EFFECTIVE_CONFIG_DIR="$HOME/.cache/kitty/effective-config"
  local EFFECTIVE_CONFIG_FILE="$EFFECTIVE_CONFIG_DIR/$KITTY_PID"

  if [ -f "$EFFECTIVE_CONFIG_FILE" ]; then
    cat "$EFFECTIVE_CONFIG_FILE"
    echo ""
    echo "=== Kitty Effective Configuration ==="
    echo "Kitty PID: $KITTY_PID"
    echo "Config file: $EFFECTIVE_CONFIG_FILE"
  else
    echo "Error: Effective config file not found at $EFFECTIVE_CONFIG_FILE" >&2
    return 1
  fi
}

# kitty: Clear cached color themes and state
#
# BACKGROUND:
#   When you kill kitty or when ~/.cache is full, kitty's cache can get corrupted,
# and colors defines in ~/.cache/kitty/rgba can override colors set in kitty.conf,
# even after restart. This function clears that cache.
#
# USE CASES:
#   - Colors in kitty.conf not taking effect (grey background instead of your color)
#   - Troubleshooting color issues
#
# WHAT GETS CLEARED:
#   - ~/.cache/kitty/rgba/*     - Cached color themes (persistent across sessions)
#   - ~/.cache/kitty/main.json   - Window size/state (optional, with --all flag)
#
# USAGE:
#   kitty.clear-cache          # Clear rgba cache (colors)
#   kitty.clear-cache --all    # Clear all cache including window state
#
# AFTER RUNNING:
#   Restart kitty for changes to take effect. Colors from kitty.conf will apply.
#
# REFERENCES:
#   - https://www.reddit.com/r/KittyTerminal/comments/1oei90r/
#   - https://github.com/kovidgoyal/kitty/discussions/6550
kitty.clear-cache() {
  local RGBA_DIR="$HOME/.cache/kitty/rgba"
  local MAIN_JSON="$HOME/.cache/kitty/main.json"
  local CLEAR_ALL=false
  local FILES_CLEARED=0

  # Parse arguments
  case "$1" in
    --all|-a)
      CLEAR_ALL=true
      ;;
  esac

  echo "=== Clearing Kitty Cache ==="
  echo ""

  # Clear rgba cache (color themes)
  if [ -d "$RGBA_DIR" ]; then
    local RGBA_COUNT=$(find "$RGBA_DIR" -type f ! -name ".lock" 2>/dev/null | wc -l)
    if [ "$RGBA_COUNT" -gt 0 ]; then
      find "$RGBA_DIR" -type f ! -name ".lock" -delete 2>/dev/null
      echo "✓ Cleared $RGBA_COUNT cached theme(s) from: $RGBA_DIR"
      FILES_CLEARED=$((FILES_CLEARED + RGBA_COUNT))
    else
      echo "ℹ No cached themes found in: $RGBA_DIR"
    fi
  else
    echo "ℹ RGBA cache directory not found: $RGBA_DIR"
  fi

  # Clear main.json (window state) if --all flag
  if [ "$CLEAR_ALL" = true ] && [ -f "$MAIN_JSON" ]; then
    rm -f "$MAIN_JSON"
    echo "✓ Cleared window state: $MAIN_JSON"
    FILES_CLEARED=$((FILES_CLEARED + 1))
  fi

  echo ""
  if [ "$FILES_CLEARED" -gt 0 ]; then
    echo "=== Summary ==="
    echo "Files cleared: $FILES_CLEARED"
    echo ""
    echo "⚠ RESTART KITTY for changes to take effect"
    echo ""
    echo "After restart, kitty will use colors from:"
    echo "  ~/.config/kitty/kitty.conf"
  else
    echo "No cache files found to clear."
    echo ""
    echo "Current kitty configuration should already be active."
  fi

  return 0
}

alias kopia='kopia --config-file=/home/ecc/.var/app/io.kopia.KopiaUI/config/kopia/repository.config'
alias ssh='kitty +kitten ssh'

# Claude Code aliases for different configurations
alias claude.glm='claude --verbose --dangerously-skip-permissions --settings ~/.claude/settings-glm.json'
alias claude.ccp-snitch='claude --verbose --dangerously-skip-permissions --settings ~/.claude/settings-ccproxy-snitch.json'
alias claude.avdm='claude --verbose --dangerously-skip-permissions --settings ~/.claude/settings-vandamme.json'

