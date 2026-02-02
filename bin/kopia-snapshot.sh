#!/bin/bash
#
# kopia-snapshot.sh
#
# This script takes an INSTANCE name (e.g., user, system, music, dev, games, vms) as an argument.
# It uses an instance-specific configuration file to perform a local snapshot
# and then syncs the local repository to a remote repository.
#
# Usage: kopia-snapshot.sh <INSTANCE>
#

# Verify the required instance parameter.

if test "$(id -u)" = 0; then
  setcap cap_dac_read_search=+ep $(which kopia)
  getcap $(which kopia)
  exit 0
fi

test "$#" -eq 1 || {
  echo "Usage: $0 <INSTANCE>" >&2
  exit 1
}

INSTANCE="$1"
TIMESTAMP=$(date +'%Y-%m-%dT%H:%M:%S')

# Load system environment if available
test -r ~/.bashrc.d/04-system-env.sh && . ~/.bashrc.d/04-system-env.sh

# Set system environment variables with fallbacks
: "${SHELLBASE_USER:=$(id -un)}"
: "${SHELLBASE_USER_HOME:=$HOME}"
: "${SHELLBASE_CONFIG_DIR:=$HOME/.config}"
: "${SHELLBASE_BIN_DIR:=$HOME/bin}"

# Set the path of the instance-specific configuration file.
# Adjust the path below to point to your actual configuration files.
CONFIG_FILE="${SHELLBASE_CONFIG_DIR}/kopia/repository.config"
#ALT_CONFIG_FILE="${SHELLBASE_CONFIG_DIR}/kopia/yandex.config"

test -r "$CONFIG_FILE" || {
  echo "Error: Config file '$CONFIG_FILE' for instance '$INSTANCE' not found." >&2
  exit 1
}

echo "[$TIMESTAMP] Starting Kopia snapshot for instance: $INSTANCE"
echo "Using config file: $CONFIG_FILE"

case "$INSTANCE" in
"$SHELLBASE_USER")
  # Backup personal files and home settings.
  BACKUP_SOURCES=("$SHELLBASE_USER_HOME")
  ;;
system)
  # Backup system configuration files.
  BACKUP_SOURCES=(/)
  ;;
music)
  # Backup music directory.
  BACKUP_SOURCES=("$HOME/Music")
  ;;
dev)
  # Backup development-related files (e.g., code repositories and IDE settings).
  BACKUP_SOURCES=("$HOME/Projects" "$HOME/github" "$HOME/.Idea" "$HOME/.PyCharm")
  ;;
games)
  # Backup local game data.
  BACKUP_SOURCES=("$HOME/Games" "$HOME/.local/share/Steam")
  ;;
vms)
  # Backup virtual machine disk images and settings.
  BACKUP_SOURCES=("$HOME/VMs")
  ;;
*)
  echo "Error: Unknown instance '$INSTANCE'. Valid instances are: user, system, music, dev, games, vms." >&2
  exit 1
  ;;
esac

echo "Backup sources: ${BACKUP_SOURCES[*]}"

# Ensure kopia cache directory exists
: "${SHELLBASE_CACHE_DIR:=$HOME/.cache}"
test -d "${SHELLBASE_CACHE_DIR}/kopia" || { sudo -u "$SHELLBASE_USER" mkdir -p "${SHELLBASE_CACHE_DIR}/kopia" || exit ;}

sudo -u "$SHELLBASE_USER" "${SHELLBASE_BIN_DIR}/backup-prepare.sh" "$@" || exit

# Password file - provider-specific, must be set in user override
: "${SHELLBASE_KOPIA_PASSWORD_FILE:?ERROR: SHELLBASE_KOPIA_PASSWORD_FILE not set. Set it in ~/.shellbase-system.env}"
pwfile="$SHELLBASE_KOPIA_PASSWORD_FILE"

kopia() {
  # test "$(id -u)" = 0 && 
  # https://kopia.discourse.group/t/cli-logs-and-content-log-directories/296
  env \
    KOPIA_LOG_DIR_MAX_FILES=10 \
    KOPIA_CONTENT_LOG_DIR_MAX_FILES=10 \
    KOPIA_PASSWORD=$(<"$pwfile") \
  kopia --config-file "$CONFIG_FILE" \
    "$@"
}

# Create a snapshot using the instance-specific config.
kopia snapshot create --description "$INSTANCE at $TIMESTAMP" \
  "${BACKUP_SOURCES[@]}" || {
    echo "[$TIMESTAMP] Snapshot for instance: $INSTANCE failed." >&2
    exit 1
  }
kopia logs cleanup --max-total-size-mb 10 --max-count 30
echo "[$TIMESTAMP] Snapshot for instance $INSTANCE completed successfully."

# After the snapshot is complete, synchronize the local repository with the remote one.

"${SHELLBASE_BIN_DIR}/kopia-remote-sync.sh" "$INSTANCE"

