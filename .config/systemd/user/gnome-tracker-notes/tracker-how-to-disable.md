See: https://unix.stackexchange.com/a/721939/46796

```shell
sudo systemctl --global mask tracker-miner-fs-3.service
sudo systemctl --global mask tracker-xdg-portal-3.service
sudo apt-mark hold tracker tracker-extract tracker-miner-fs
rm -rf ~/.cache/tracker3/
```
