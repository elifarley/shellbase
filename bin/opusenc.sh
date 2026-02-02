#!/bin/sh

srcfolder="$1"; shift
test -e "$srcfolder" || { echo "Invalid path: '$srcfolder'"; exit 1 ;}

_opusenc() {
  local f="$1"; shift
  test -e "${f%.*}".opus && return
  opusenc --downmix-mono --artist NotebookLM --bitrate 24 "$@" "$f" - > "${f%.*}".opus
}

test -f "$srcfolder" && {
  _opusenc "$srcfolder"
  exit
}

for f in "$srcfolder"/*.wav ; do
  f="$(readlink -f "$f")"; test -f "$f" || continue

  _opusenc "$f" "$@" || {
	  echo "FAILED: '$(basename "$f")'"
  }
done

