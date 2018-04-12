#!/bin/sh

TRACKER_DIR='/volumes/tmp/cache-ecc-tmpfs/tracker'
test -d "$TRACKER_DIR" || exit 0

killall /usr/lib/tracker-{miner-apps,extract,miner-fs,store}
du -hs "$TRACKER_DIR"
rm -rf "$TRACKER_DIR"
exit 0
