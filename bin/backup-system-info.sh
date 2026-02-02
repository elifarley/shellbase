#!/bin/sh

# Use system environment variable if set, otherwise use default
backup_dir="${SHELLBASE_BACKUP_DIR:-$HOME/Documents/system-info}"
flatpakbkp="$backup_dir/app-list-flatpak.txt"
snapbkp="$backup_dir/app-list-snap.txt"
aptbkp="$backup_dir/app-list-apt.txt"
ppabkp="$backup_dir/ppa.txt"
hostsbkp="$backup_dir/hosts.txt"

# Function to update file only if content differs, showing only changed lines
update_if_changed() {
    local temp_file source_cmd target_file
    temp_file=$(mktemp)
    source_cmd="$1"
    target_file="$2"

    eval "$source_cmd" | sort > "$temp_file"

    # Check if target file exists
    if [ ! -f "$target_file" ]; then
        echo "Creating new file: $target_file" >&2
        mv "$temp_file" "$target_file"
    # Compare files and show minimal diff if different
    elif ! cmp -s "$temp_file" "$target_file"; then
        printf "###\n\n" >&2
        echo "Added to $target_file:" >&2
        diff --changed-group-format='%<' --unchanged-group-format='' "$target_file" "$temp_file" | grep -v '^$' >&2
        printf "\nRemoved from $target_file:\n" >&2
        diff --changed-group-format='%>' --unchanged-group-format='' "$target_file" "$temp_file" | grep -v '^$' >&2
        printf "\n###\n\n" >&2
        mv "$temp_file" "$target_file"
    else
        rm "$temp_file"
    fi
}

mkdir -p "$backup_dir"

# Process flatpak list
update_if_changed "flatpak list" "$flatpakbkp"

# Process snap list
update_if_changed "snap list" "$snapbkp"

update_if_changed "apt 2>/dev/null list --installed | grep -v 'Listing...'" "$aptbkp"
update_if_changed "grep -r '^deb ' /etc/apt/sources.list /etc/apt/sources.list.d/" "$ppabkp"
update_if_changed "sed -nEe '/# BEGIN HEADER/,/# END HEADER/p' /etc/hosts | grep -Ev '^# \S+ HEADER'" "$hostsbkp"

# Cloud sync - only if SHELLBASE_CLOUD_DIR is set (provider-specific, not tracked)
: "${SHELLBASE_CLOUD_DIR:?ERROR: SHELLBASE_CLOUD_DIR not set. Set it in ~/.shellbase-system.env for cloud sync}"
rsync -ah "$backup_dir" "$SHELLBASE_CLOUD_DIR/backup/"
