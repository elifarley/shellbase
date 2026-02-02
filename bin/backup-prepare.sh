#!/bin/bash

create_cachedir_tag() {
  local target_dir="$1"
  test "$target_dir" || {
    echo "Usage: create_cachedir_tag <directory>"
    return 1
  }

  test -d "$target_dir" || {
    echo "Error: '$target_dir' is not a directory."
    return 1
  }

  # Full path to the tag file.
  local tag_file="${target_dir%/}/CACHEDIR.TAG"

  test -r "$tag_file" && return

  # Write the signature to the file.
  echo "Signature: 8a477f597d28d172789f06886806bc55" > "$tag_file"

  ls -l "$tag_file"
}

list_cache_directories() {
  local base_dir="$1"

  # Verify that an argument (base directory) is provided.
  test "$base_dir" || {
    echo "Usage: list_cache_directories <base_directory>" >&2
    return 1
  }

  # Verify that the provided argument is a directory.
  test -d "$base_dir" || {
    echo "Error: '$base_dir' is not a valid directory" >&2
    return 1
  }

  # Use find to search for directories with "cache" (or tmp patterns) in their names, ignoring case,
  # and exclude any directory that contains a direct child named "CACHEDIR.TAG".
  # The '! -exec test -f "{}/CACHEDIR.TAG" \;' part ensures that if a directory already has the tag file, it won't be listed.
  # The -printf '%P\n' option prints the relative path (relative to the base directory).
  #
  # IMPORTANT: Exclude container overlay storage.
  # Container runtime overlay directories (Podman, Docker) contain root-owned files that cause
  # permission errors when the script tries to create CACHEDIR.TAG files inside them. Since these
  # dirs are under ~/.local (within the user's home), the find traversal would normally encounter
  # them. We prune them early to avoid these errors.
  #
  # Covered paths:
  #   - ~/.local/share/containers/storage/* (Podman rootless)
  #   - ~/.docker/overlay2/* (Docker rootless)
  #
  # NOTE: The -type d predicate MUST come AFTER the prune conditions (-prune -o), not before.
  # When using find with complex expressions containing -o (OR), predicates placed before the
  # first -o apply only to the first branch. Placing -type d after -prune -o ensures it applies
  # to the pattern matching branch that actually prints results. Without this, find may return
  # files matching the pattern (e.g., "cache.js") instead of just directories, causing
  # "is not a directory" errors when create_cachedir_tag tries to process them.
  #
  # Note: /var/cache and other system dirs are not processed by this script (it only handles paths
  # under ~), so they don't need special handling here.
  find "$base_dir" \
    \( -path '*/containers/storage/*' -o -path '*/.docker/overlay2/*' \) -prune -o \
    -type d \
    \( -iname '*cache*' -o -iname 'tmp*' -o -iname '*tmp' \) \
    \( -exec test -f "{}/../CACHEDIR.TAG" -o -f "{}/../../CACHEDIR.TAG" \; -prune -o -printf '%P\n' \)
}

# Load system environment if available
test -r ~/.bashrc.d/04-system-env.sh && . ~/.bashrc.d/04-system-env.sh
: "${SHELLBASE_USER:=$(id -un)}"

test "$1" != "$SHELLBASE_USER" && exit 0

: "${SHELLBASE_BIN_DIR:=$HOME/bin}"
"$SHELLBASE_BIN_DIR/backup-system-info.sh" || exit

echo "Tagging cache and temporary dirs..." >&2

# Process specific directories by creating the CACHEDIR.TAG file for each
for cachedir in ~/.local/share/Steam/ubuntu* ~/.Idea* ~/apps/idea-* ~/.PyCharm* ~/.sylpheed* ~/ubuntu*
do
  test -d "$cachedir" || continue
  create_cachedir_tag "$cachedir" || exit
done

for cachedir in .cache .local/share/Trash .local/share/tracker .local/share/JetBrains .local/share/lutris/runners .local/share/lutris/runtime \
.local/share/Steam/steamapps  .local/share/Steam/package .local/share/Steam/logs \
.local/share/flatpak/repo/objects .local/share/flatpak/app .local/share/flatpak/runtime \
.local/share/containers/storage .docker \
.m2 .dcrd .rustup .mozilla/firefox .gradle/wrapper .cargo .dashcore .pivx .electron .ipfs .minikube/machines \
linux32 Downloads Music Games Dropbox Yandex.Disk Videos VirtualBox\ VMs bind-mounts
do
  test -d ~/"$cachedir" || continue
  create_cachedir_tag ~/"$cachedir" || exit
done

# For each base directory, list its cache directories (without those that already have CACHEDIR.TAG),
# and then echo the command that could be used to create the tag.
for base_dir in .config .local .var .minikube .gradle .PyCharm* .nv .npm .openjfx .mcf .FBReader
do
  test -f ~/"$base_dir"/CACHEDIR.TAG && continue
  while read -r line; do
    create_cachedir_tag ~/"$base_dir/$line"
  done <<< "$(list_cache_directories ~/"$base_dir")"
done

# TODO Delete *.hprof

