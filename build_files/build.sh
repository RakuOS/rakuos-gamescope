#!/bin/bash

set -ouex pipefail
FEDORA_VERSION=$(rpm -E %fedora)

## Install packages
dnf5.real -y install @fonts @hardware-support \
  plasma-desktop \
  plasma-workspace \
  plasma-workspace-wayland \
  plasma-browser-integration \
  kscreen \
  plasma-login-manager \
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
  plasma-foreground-booster-dmemcg \
  rakuos-welcome-qt \
  rakuos-software-qt

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
rm -rf /usr/share/wallpapers/F43

#KDE customizations
sed -i '$r /usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/rakuos-pins.js' /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js

## Enable Services
systemctl enable plasmalogin.service
