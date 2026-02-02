#!/bin/sh

# Load system environment if available
test -r ~/.bashrc.d/04-system-env.sh && . ~/.bashrc.d/04-system-env.sh
: "${SHELLBASE_USER:=$(id -un)}"

INSTANCE="$1"
# Remote path is provider-specific - must be set in user override
: "${SHELLBASE_KOPIA_REMOTE_PATH:?ERROR: Set SHELLBASE_KOPIA_REMOTE_PATH in ~/.shellbase-system.env}"
REMOTE_PATH="$SHELLBASE_KOPIA_REMOTE_PATH"

case "$INSTANCE" in
  "$SHELLBASE_USER")
    # Skip sync for primary user instance (typically handled separately)
    exit 0
    ;;
esac

echo "Syncing local repository to remote repository at $REMOTE_PATH; $(rclone --version)"
# See https://rclone.org/yandex/
# kopia repository sync-to rclone --config "$CONFIG_FILE" --remote-path "$REMOTE_PATH"
mountpoint ~/bind-mounts/backup-kopia >/dev/null || {
  echo "Expected a mountpoint at ~/bind-mounts/backup-kopia" >&2
  exit 1
}

rclone sync -v --transfers=32 --use-mmap ~/bind-mounts/backup-kopia "$REMOTE_PATH" && \
rclone --max-depth 1 lsl "$REMOTE_PATH"

test "$?" -eq 0 || {
  echo "Repository sync for instance: $INSTANCE failed." >&2
  exit 1
}

echo "Repository sync for instance '$INSTANCE' completed successfully."

