#!/usr/bin/env bash
# Show the WM_CLASS of the focused window as seen by Solaar's GNOME extension.
# Use this to find the correct value for Process: rules in rules.yaml.
#
# Usage: Focus the target app, then run:
#   solaar-wmclass.sh [DELAY]
#
# DELAY defaults to 5 seconds, giving you time to Alt-Tab to the target window.

set -euo pipefail

delay="${1:-5}"

echo "Focus the target window within ${delay} seconds..."
sleep "$delay"

gdbus call --session \
  --dest org.gnome.Shell \
  --object-path /io/github/pwr_solaar/solaar \
  --method io.github.pwr_solaar.solaar.ActiveWindow
