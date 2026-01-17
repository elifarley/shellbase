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

alias kopia='kopia --config-file=/home/ecc/.var/app/io.kopia.KopiaUI/config/kopia/repository.config'
alias ssh='kitty +kitten ssh'

# Claude Code aliases for different configurations
alias claude.glm='claude --verbose --dangerously-skip-permissions --settings ~/.claude/settings-glm.json'
alias claude.ccp-snitch='claude --verbose --dangerously-skip-permissions --settings ~/.claude/settings-ccproxy-snitch.json'
alias claude.avdm='claude --verbose --dangerously-skip-permissions --settings ~/.claude/settings-vandamme.json'
