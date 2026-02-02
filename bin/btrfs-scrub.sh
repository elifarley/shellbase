#!/bin/bash

# See /etc/systemd/system/btrfs-scrub-@.service
# See /etc/systemd/system/btrfs-scrub-@*.timer

btrfs scrub start -Bd -c 2 -n 4 /volumes/"$1"

