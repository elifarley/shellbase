# 19-desktop.sh: Desktop environment and media aliases/functions
# pipewire: Audio subsystem restart
# Future: display, input, notification helpers

# Restart the PipeWire audio stack when sound stops playing.
# Covers pipewire (core daemon), pipewire-pulse (PulseAudio compat), and wireplumber (session manager).
alias audiofix='systemctl --user restart pipewire pipewire-pulse wireplumber'
