#!/bin/bash

CONFIG_DIR="/storage/.config"
SUSPEND_DIR="${CONFIG_DIR}/real_suspend"
SYSTEMD_DIR="${CONFIG_DIR}/system.d"
SERVICE_NAME="bind_suspend.service"
SERVICE_FILE="${SYSTEMD_DIR}/${SERVICE_NAME}"
BIND_SOURCE="${SUSPEND_DIR}/rocknix-real-suspend"
BIND_TARGET="/usr/bin/rocknix-fake-suspend"

install_service() {
mkdir -p "${SUSPEND_DIR}"
mkdir -p "${SYSTEMD_DIR}"

cat << 'EOF' > "${BIND_SOURCE}"
#!/bin/bash

SOURCE="$1"
ACTION="$2"

for path in $(find /sys/devices -type f -name wakeup | grep -i usb); do
[[ -w "$path" ]] && echo disabled > "$path"
done

do_suspend() {

WIFI_STATE=$(rocknix-settings --command status --key wifi.enabled | awk '{print $NF}')
WIFI_WAS_ON=false
if [[ "$WIFI_STATE" == "1" ]]; then
WIFI_WAS_ON=true
wifictl disable
rocknix-settings --command disable --key wifi.enabled
fi

BT_STATE=$(rocknix-settings --command status --key controllers.bluetooth.enabled | awk '{print $NF}')
BT_WAS_ON=false
if [[ "$BT_STATE" == "1" ]]; then
BT_WAS_ON=true
bluetoothctl radio off
rocknix-settings --command disable --key controllers.bluetooth.enabled
fi

echo mem > /sys/power/state

if $WIFI_WAS_ON; then
wifictl enable
rocknix-settings --command enable --key wifi.enabled
fi

if $BT_WAS_ON; then
bluetoothctl radio on
rocknix-settings --command enable --key controllers.bluetooth.enabled
fi
}

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

cat << EOF > "${SUSPEND_DIR}/bind_suspend.sh"
#!/bin/bash
if mountpoint -q "${BIND_TARGET}" || [ -e "${BIND_TARGET}" ]; then
umount -l "${BIND_TARGET}"
rm -f "${BIND_TARGET}"
fi
mount --bind "${BIND_SOURCE}" "${BIND_TARGET}"
EOF

chmod +x "${SUSPEND_DIR}/bind_suspend.sh"

cat << EOF > "${SERVICE_FILE}"
[Unit]
Description=Bind Rocknix Real Suspend at Boot
After=multi-user.target

[Service]
Type=oneshot
ExecStart=${SUSPEND_DIR}/bind_suspend.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
systemctl start "${SERVICE_NAME}"

}

uninstall_service() {
systemctl stop "${SERVICE_NAME}"
systemctl disable "${SERVICE_NAME}"

if mountpoint -q "${BIND_TARGET}"; then
umount -l "${BIND_TARGET}"
fi

rm -rf "${SUSPEND_DIR}"
rm -f "${SERVICE_FILE}"
systemctl daemon-reload
umount -l "${BIND_TARGET}"
}

if [ ! -f "${SERVICE_FILE}" ]; then
install_service
else
uninstall_service
fi

exit 0
