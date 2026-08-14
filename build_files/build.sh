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
# Fixme: remove --allowerasing
rum install -y --allowerasing akonadi-server \
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
  kdotool \
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
  sddm \
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
  udisks2 \
  steam \
  inputplumber \
  wireplumber \
  steam-devices \
  gamescope \
  gamescope-session \
  gamescope-session-steam \
  steamos-manager \
  steamos-manager-powerstation

rum install -y steamos-manager-powerstation-gamescope-session-plus steamos-manager-gamescope-session-plus

## Remove packages
rum remove -y plasma-discover \
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

## Fix steamosctl
sed -i 's|Exec=/bin/false|Exec=/usr/lib/steamos-manager|g' /usr/share/dbus-1/system-services/com.steampowered.SteamOSManager1.service

## Enable Services
systemctl enable sddm.service
systemctl enable inputplumber.service
systemctl enable autologin-setup.service
systemctl enable steamos-manager.service
systemctl enable --global steamos-manager-session-cleanup.service
systemctl enable --global steamos-manager.service
