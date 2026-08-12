#!/bin/bash

TARGET_USER=$(awk -F: '$3 >= 1000 && $3 != 65534 {print $1; exit}' /etc/passwd)

CONF_DIR="/etc/sddm.conf.d"
CONF_FILE="$CONF_DIR/autologin.conf"

if [ -f "$CONF_FILE" ]; then
    exit 0
fi

mkdir -p "$CONF_DIR"
cat <<EOF > "$CONF_FILE"
[Autologin]
User=$TARGET_USER
Session=gamescope-session-steam.desktop
EOF
