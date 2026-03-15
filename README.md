# Rocknix Real Suspend Manager for RG35XXSP

A lightweight install/uninstall script to handle **real suspend** (`echo mem > /sys/power/state`) on Anbernic RG35XXSP devices running the [ROCKNIX](https://github.com/ROCKNIX/distribution-nightly/releases) Gaming Handheld Linux Operating System.

## Features

- **Automatic binding:** Launch from the Ports menu to bind a custom suspend script to `/usr/bin/rocknix-fake-suspend`.
- **Persistent across reboots:** Systemd `oneshot` service ensures the suspend handler stays active.
- **Wi-Fi and Bluetooth management:** Disables Wi-Fi and Bluetooth before suspend to prevent lockups and restores them after resume.
- **Easy uninstall:** Re-run the script to remove the binding, scripts, and systemd service cleanly.
