#!/bin/bash
# Wrapper for shadowcache system service - provides indirection for user home path
# Sources SHELLBASE_USER from $PERSISTENT/.shellbase-system.env or /etc/default/shellbase
#
# This wrapper enables portability for system services running as root.
# Systemd does NOT expand %h in system services, and has no specifier for
# a regular user's home directory. This wrapper sources configuration to
# determine the correct user context.

set -euo pipefail
# Get PERSISTENT from environment or use default (no trailing slash)
PERSISTENT="${SHADOWCACHE_PERSISTENT:-/volumes/APM-cache}"

# Try $PERSISTENT first (shellbase architecture), fallback to /etc/default
if [[ -f ${PERSISTENT}/.shellbase-system.env ]]; then
    source "${PERSISTENT}/.shellbase-system.env"
elif [[ -f /etc/default/shellbase ]]; then
    source /etc/default/shellbase
else
    echo "ERROR: Cannot find shellbase configuration" >&2
    echo "Tried: ${PERSISTENT}/.shellbase-system.env, /etc/default/shellbase" >&2
    exit 1
fi

: "${SHELLBASE_USER:?ERROR: SHELLBASE_USER not set in configuration}"

# Execute shadowcache.sh with correct user context
exec "/home/${SHELLBASE_USER}/bin/shadowcache.sh" "$@"
