# 20-local.sh: Local tool initialization and final setup
# ssh-agent: Automatic start and key loading
# Python: Activate venv if no python found
# nvm: Node Version Manager loading
# hug: Humane Git activation

# Start ssh-agent if not running and SSH_AUTH_SOCK is not set
if [ -z "$SSH_AUTH_SOCK" ]; then
    # Check if agent is already running
    if [ -f ~/.ssh-agent-env ]; then
        . ~/.ssh-agent-env > /dev/null
    fi
    # Verify agent is responsive
    if ! ssh-add -l &>/dev/null; then
        ssh-agent -s > ~/.ssh-agent-env
        . ~/.ssh-agent-env
        ssh-add ~/.ssh/id_ed25519
    fi
fi

# Activate Python in user's venv if no python found
command -v python || {
  test -r ~/.venv/bin/activate && . ~/.venv/bin/activate
}

# Local-only config
test -r ~/.shell-local-conf && . ~/.shell-local-conf

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Activate Hug SCM if available (uses SHELLBASE_PROJECT_ROOT from 04-system-env.sh)
if [ -n "$SHELLBASE_PROJECT_ROOT" ]; then
  hug_activate="$SHELLBASE_PROJECT_ROOT/hug-scm/bin/activate"
  [ -r "$hug_activate" ] && . "$hug_activate"
else
  # Fallback to hardcoded path for backward compatibility
  test -r ~/IdeaProjects/hug-scm/bin/activate && . ~/IdeaProjects/hug-scm/bin/activate
fi
