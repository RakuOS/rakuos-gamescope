#!/bin/bash

set -ouex pipefail
CENTOS_VERSION=$(rpm -E %rhel)

## Install packages
dnf5.real -y install @fonts @hardware-support \
  plasma-desktop \
  plasma-workspace \
  plasma-workspace-wayland \
  plasma-browser-integration \
  kscreen \
  sddm \
  kwin \
  kmenuedit \
  kinfocenter \
  plasma-nm \
  plasma-pa \
  kdegraphics-thumbnailers \
  breeze-icon-theme \
  breeze-gtk \
  bluedevil \
  bluez \
  bluez-obexd \
  kde-gtk-config \
  kcm_systemd \
  kwalletmanager5 \
  rakuos-welcome-qt \
  rakuos-software-qt

## Remove packages
dnf5.real -y remove plasma-discover \
  plasma-discover-offline-updates \
  plasma-discover-packagekit \
  plasma-welcome \
  plasma-welcome-fedora


## Remove Fedora Wallpapers
rm /usr/share/wallpapers/Fedora
rm -rf /usr/share/wallpapers/F43

#KDE customizations
sed -i '$r /usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/rakuos-pins.js' /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js

## Enable Services
systemctl enable sddm.service
