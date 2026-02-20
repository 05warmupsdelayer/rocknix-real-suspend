# Rocknix Real Suspend Manager for RG35XXSP

A simple install/uninstall script to manage real suspend (`echo mem > /sys/power/state`) on Anbernic RG35XXSP devices.

## Features

- When launched from the Ports menu, binds a custom suspend script to `/usr/bin/rocknix-fake-suspend`.
- Persistent across reboots via a systemd `oneshot` service.
- Checks Wi-Fi and disables it before suspend, restoring it after lid open to prevent lockups.
- Built-in uninstall: re-run the script to remove the binding, script files, and systemd service.
