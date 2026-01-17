#!/bin/sh
# Remove stale IntelliJ IDEA lock files
# Works with both IdeaIC* (old) and IntelliJIdea* (new) directory patterns

jetbrains_config=~/.var/app/com.jetbrains.IntelliJ-IDEA-Community/config/JetBrains

# Exit silently if JetBrains config directory doesn't exist
[ -d "$jetbrains_config" ] || exit 0

for lock in "$jetbrains_config"/*/.lock; do
  [ -f "$lock" ] && rm -fv "$lock"
done

# Remind user how to start IntelliJ
echo flatpak run com.jetbrains.IntelliJ-IDEA-Community
