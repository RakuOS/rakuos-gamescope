#!/bin/bash

SESSION="$1"
TARGET_USER=$(awk -F: '$3 >= 1000 && $3 != 65534 {print $1; exit}' /etc/passwd)

CONF_DIR="/etc/plasmalogin.conf.d"
CONF_FILE="$CONF_DIR/autologin.conf"

mkdir -p "$CONF_DIR"
cat <<EOF > "$CONF_FILE"
[Autologin]
Relogin=true
User=$TARGET_USER
Session=$SESSION.desktop
EOF
