#!/bin/bash

set -ouex pipefail

# Disable Terra again — build.sh only enabled it temporarily for the install
# step above; third-party repos ship disabled by default.
rum config-manager --default --set-disabled terra
rum config-manager --default --set-disabled 'rpmfusion-*'

# Write the DE identifier so rakuos-overlay-mount can detect a DE change at
# boot and trigger a soft reset to rebuild the overlay from packages.list.
echo "kde" > /usr/share/rakuos/de-name


# System accounts this image's package installs created go to nss-altfiles
# (/usr/lib/passwd, /usr/lib/group) like the base image's. Accounts without a
# pinned ID are listed in the log: add them to rakuos-base's
# build_files/bootstrap/static-ids/ so they keep their ID in every build.
# (Skipped on a base image built before finalize-accounts existed.)
if [ -x /usr/libexec/rakuos/finalize-accounts ]; then
    /usr/libexec/rakuos/finalize-accounts
fi
