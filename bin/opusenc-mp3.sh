#!/bin/sh

srcfolder="$1"; shift
test -e "$srcfolder" || { echo "Invalid path: '$srcfolder'"; exit 1 ;}

for f in "$srcfolder"/*.mp3 ; do
  f="$(readlink -f "$f")"; test -f "$f" || continue

  sox -D "$f" -t aiff - | opusenc "$@" - - > "${f%.*}".opus || {
	  echo "FAILED: '$(basename "$f")'"
  }
done

