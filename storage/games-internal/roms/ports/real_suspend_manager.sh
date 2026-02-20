#!/bin/bash

CONFIG_DIR="/storage/.config"
SUSPEND_DIR="${CONFIG_DIR}/real_suspend"
SYSTEMD_DIR="${CONFIG_DIR}/system.d"
SERVICE_NAME="bind_suspend.service"
SERVICE_FILE="${SYSTEMD_DIR}/${SERVICE_NAME}"
BIND_SOURCE="${SUSPEND_DIR}/rocknix-fake-suspend"
BIND_TARGET="/usr/bin/rocknix-fake-suspend"

log() {
    logger "[RealSuspendManager] $1"
}

install_service() {
    mkdir -p "${SUSPEND_DIR}"
    mkdir -p "${SYSTEMD_DIR}"

    # Write fake suspend script
cat << 'EOF' > "${BIND_SOURCE}"
#!/bin/bash

SOURCE="$1"
ACTION="$2"

echo "Disabling USB wake sources..."
for path in $(find /sys/devices -type f -name wakeup | grep -i usb); do
    [[ -w "$path" ]] && echo disabled > "$path"
done

do_suspend() {
    # Check Wi-Fi state using rocknix-settings
    WIFI_STATE=$(rocknix-settings --command status --key wifi.enabled | awk '{print $NF}')
    WIFI_WAS_ON=false
    if [[ "$WIFI_STATE" == "1" ]]; then
        WIFI_WAS_ON=true
        echo "Disabling Wi-Fi..."
        wifictl disable 2>/dev/null
        rocknix-settings --command disable --key wifi.enabled
    fi

    echo "Suspending system..."
    echo mem > /sys/power/state

    # Restore Wi-Fi only if it was on
    if $WIFI_WAS_ON; then
        echo "Re-enabling Wi-Fi..."
        wifictl enable 2>/dev/null
        rocknix-settings --command enable --key wifi.enabled
    fi
}

# Main event dispatch
case "${SOURCE}" in
    lid)
        if [[ "${ACTION}" = "close" ]]; then
            do_suspend
        fi
        ;;
esac

exit 0
EOF

    chmod +x "${BIND_SOURCE}"

    # Write bind script for systemd
cat << EOF > "${SUSPEND_DIR}/bind_suspend.sh"
#!/bin/bash
# Unmount if target exists
if mountpoint -q "${BIND_TARGET}" || [ -e "${BIND_TARGET}" ]; then
    umount -l "${BIND_TARGET}" 2>/dev/null
    rm -f "${BIND_TARGET}" 2>/dev/null
fi
mount --bind "${BIND_SOURCE}" "${BIND_TARGET}"
EOF

    chmod +x "${SUSPEND_DIR}/bind_suspend.sh"

    # Systemd service
cat << EOF > "${SERVICE_FILE}"
[Unit]
Description=Bind Rocknix Fake Suspend at Boot
After=multi-user.target

[Service]
Type=oneshot
ExecStart=${SUSPEND_DIR}/bind_suspend.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Reload, enable, and start service
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}"
    systemctl start "${SERVICE_NAME}"

    log "Installed and service started"
}

uninstall_service() {
    # Stop and disable service first
    systemctl stop "${SERVICE_NAME}" 2>/dev/null
    systemctl disable "${SERVICE_NAME}" 2>/dev/null

    # Unbind if mounted
    if mountpoint -q "${BIND_TARGET}"; then
        umount -l "${BIND_TARGET}" 2>/dev/null
        log "Fake suspend unbound from ${BIND_TARGET}"
    fi

    # Remove files
    rm -rf "${SUSPEND_DIR}"
    rm -f "${SERVICE_FILE}"
    systemctl daemon-reload
	umount -l "${BIND_TARGET}" 2>/dev/null
    log "Service uninstalled and files removed"
}

# ---- Main ----
if [ ! -f "${SERVICE_FILE}" ]; then
    install_service
else
    uninstall_service
fi

exit 0
