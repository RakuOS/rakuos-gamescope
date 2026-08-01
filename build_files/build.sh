#!/bin/bash

set -ouex pipefail
FEDORA_VERSION=$(rpm -E %fedora)

# On the staging branch (RAKUOS_STAGING=1, set via --build-arg from CI)
# install the staging os-release identity instead of the stable one, so
# staging images identify themselves as "RakuOS KDE Staging".
RAKUOS_RELEASE_PKG="rakuos-release-kde"
if [ "${RAKUOS_STAGING:-0}" = "1" ]; then
    RAKUOS_RELEASE_PKG="rakuos-release-kde-staging"
fi

## Install packages
dnf5.real -y install akonadi-server \
  akonadi-server-mysql \
  ark \
  bluedevil \
  bluez \
  bluez-obexd \
  bluez-cups \
  breeze-gtk \
  breeze-icon-theme \
  dolphin \
  flatpak-kcm \
  fprintd-pam \
  gwenview \
  icoutils \
  kaccounts-integration-qt6 \
  kaccounts-providers \
  kate \
  kcalc \
  kcm_systemd \
  kde-gtk-config \
  kde-partitionmanager \
  kdegraphics-thumbnailers \
  kf6-kimageformats \
  kinfocenter \
  kio-admin \
  kio-gdrive \
  kmenuedit \
  konsole \
  kscreen \
  ksshaskpass \
  kwalletmanager5 \
  kwin \
  libappindicator-gtk3 \
  okular \
  pam-kwallet \
  plasma-browser-integration \
  plasma-desktop \
  plasma-foreground-booster-dmemcg \
  plasma-login-manager \
  plasma-nm \
  plasma-pa \
  plasma-systemmonitor \
  plasma-workspace \
  plasma-workspace-wayland \
  qt6-qtimageformats \
  ${RAKUOS_RELEASE_PKG} \
  rakuos-software-qt \
  rakuos-welcome-qt \
  samba-usershares \
  signon-kwallet-extension \
  spectacle \
  systemd-oomd-defaults \
  udisks2

## Remove packages
dnf5.real -y remove plasma-discover \
  plasma-discover-offline-updates \
  plasma-discover-packagekit \
  plasma-welcome \
  plasma-welcome-fedora

## Remove Fedora Look and Feel
rm -rf /usr/share/plasma/look-and-feel/org.fedoraproject.fedora.desktop
rm -rf /usr/share/plasma/look-and-feel/org.fedoraproject.fedoradark.desktop
rm -rf /usr/share/plasma/look-and-feel/org.fedoraproject.fedoralight.desktop

## Remove Fedora Wallpapers
rm /usr/share/wallpapers/Fedora
rm -rf /usr/share/wallpapers/F44

#KDE customizations
rm /usr/share/applications/org.kde.foreground-booster.desktop
sed -i '$r /usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/rakuos-pins.js' /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js

## Enable Services
systemctl enable plasmalogin.service
