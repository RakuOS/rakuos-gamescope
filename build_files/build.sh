#!/bin/bash

set -ouex pipefail
FEDORA_VERSION=$(rpm -E %fedora)

# On the staging branch (RAKUOS_STAGING=1, set via --build-arg from CI)
# install the staging os-release identity instead of the stable one, so
# staging images identify themselves as "RakuOS KDE Staging".
RAKUOS_RELEASE_PKG="rakuos-release-gamescope"
RAKUOS_RELEASE_BAD_PKG="rakuos-release-kde"
if [ "${RAKUOS_STAGING:-0}" = "1" ]; then
    RAKUOS_RELEASE_PKG="rakuos-release-gamescope-staging"
    RAKUOS_RELEASE_BAD_PKG="rakuos-release-kde-staging"
fi

rum remove -y ${RAKUOS_RELEASE_BAD_PKG}

## Install packages
# Fixme: remove --allowerasing
rum install -y akonadi-server \
  ${RAKUOS_RELEASE_PKG} \
  steam \
  inputplumber \
  wireplumber \
  steam-devices \
  powerbuttond \
  gamescope \
  gamescope-session \
  gamescope-session-steam

## Remove packages
rum remove -y cardwire

## Enable Services
systemctl enable inputplumber.service
systemctl enable autologin-setup.service
systemctl mask autologin-setup-plasma.service
systemctl --global enable steamos-powerbuttond.service
