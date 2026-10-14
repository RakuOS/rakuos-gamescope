#!/bin/bash

set -ouex pipefail
FEDORA_VERSION=$(rpm -E %fedora)

# Terra ships disabled by default (third-party repos are opt-in), so enable
# it here in case any packages below come from Terra; post-build.sh disables
# it again before the image is finalized.
rum config-manager --default --set-enabled terra

# RPM Fusion is disabled in the base image too; turn its default repos back
# on (the list base post-build.sh recorded). post-build.sh disables them again.
rum config-manager --default --set-enabled $(cat /usr/share/rakuos/rpmfusion-default-repos)

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

# ISA level (v2/v3/v4) this image is built for, set by CI via
# --build-arg RAKUOS_ISA_LEVEL to match the base image leg. Swap the base
# image's default kernel-rakuos-<isa> for our handheld-oriented
# kernel-rakuos-deck-<isa> build.
ISA_LEVEL="${RAKUOS_ISA_LEVEL:-v2}"
KERNEL_RAKUOS_PKG="kernel-rakuos-${ISA_LEVEL}"
KERNEL_DECK_PKG="kernel-rakuos-deck-${ISA_LEVEL}"
if [ "${RAKUOS_STAGING:-0}" = "1" ]; then
    KERNEL_RAKUOS_PKG="${KERNEL_RAKUOS_PKG}-staging"
    KERNEL_DECK_PKG="${KERNEL_DECK_PKG}-staging"
fi

rum remove -y \
    ${KERNEL_RAKUOS_PKG} \
    ${KERNEL_RAKUOS_PKG}-core \
    ${KERNEL_RAKUOS_PKG}-modules \
    ${KERNEL_RAKUOS_PKG}-devel \
    ${KERNEL_RAKUOS_PKG}-devel-matched

rm -rf /boot/* /usr/lib/modules/* /lib/modules/*

rum install -y \
    ${KERNEL_DECK_PKG} \
    ${KERNEL_DECK_PKG}-core \
    ${KERNEL_DECK_PKG}-modules \
    ${KERNEL_DECK_PKG}-devel \
    ${KERNEL_DECK_PKG}-devel-matched

# depmod/dracut for the new kernel-deck happen in drivers.sh, after akmods
# and MOK module/kernel signing so the initramfs is built from the final,
# signed module set (same order rakuos-base uses for its own kernel).

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
  gamescope-session-steam \
  jupiter-fan-control \
  jupiter-hw-support \
  steamdeck-dsp \
  steamdeck-firmware

## Remove packages
rum remove -y cardwire

## Enable Services
systemctl enable inputplumber.service
# steamdeck-dsp: copy the Deck's pipewire/wireplumber hardware profiles
# (speaker DSP filter chain, mic, default-device rules) into /etc at boot
systemctl enable pipewire-sysconf.service
systemctl enable wireplumber-sysconf.service
systemctl enable autologin-setup.service
systemctl mask autologin-setup-plasma.service
systemctl --global enable steamos-powerbuttond.service
