#!/bin/sh
# Installs or updates the SMS gateway on a Raspberry Pi (Debian / Pi OS).
# Idempotent: run it again after copying a new version of this folder.
# Never overwrites an existing /etc/cm-sms-gateway.conf.
#
#   sudo ./install.sh
set -eu
cd "$(dirname "$0")"

if [ "$(id -u)" -ne 0 ]; then
  echo "must run as root: sudo $0" >&2
  exit 1
fi

if ! dpkg -s gammu python3-gammu python3-requests >/dev/null 2>&1; then
  apt-get update
  apt-get install -y --no-install-recommends gammu python3-gammu python3-requests
fi

if ! id cm-gateway >/dev/null 2>&1; then
  useradd --system --no-create-home --shell /usr/sbin/nologin cm-gateway
fi

install -d -m 755 /opt/cm-sms-gateway
install -m 644 cm_sms_gateway.py /opt/cm-sms-gateway/
install -m 755 cm-modem-reset /opt/cm-sms-gateway/
install -m 644 cm-sms-gateway.service cm-modem-reset.service cm-modem-reset.path /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now cm-modem-reset.path

# Readable by the daemon's user, not by others: it holds the API token.
if [ ! -e /etc/cm-sms-gateway.conf ]; then
  install -m 640 -o root -g cm-gateway cm-sms-gateway.conf.example /etc/cm-sms-gateway.conf
fi

if grep -q '^token = CHANGEZ-MOI' /etc/cm-sms-gateway.conf; then
  echo "Edit /etc/cm-sms-gateway.conf (url, token, line_phone), then:"
  echo "  sudo systemctl enable --now cm-sms-gateway"
else
  systemctl enable cm-sms-gateway
  systemctl restart cm-sms-gateway
  echo "cm-sms-gateway (re)started: journalctl -u cm-sms-gateway -f"
fi
