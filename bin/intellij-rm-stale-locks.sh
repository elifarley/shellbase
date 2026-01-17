jetbrains_config=~/.var/app/com.jetbrains.IntelliJ-IDEA-Community/config/JetBrains
for lock in "$jetbrains_config"/*/.lock; do
  [ -f "$lock" ] && rm -fv "$lock"
done
echo flatpak run com.jetbrains.IntelliJ-IDEA-Community
