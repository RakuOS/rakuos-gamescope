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

# Swap the base image's kernels (both kernel-rakuos variants) for both
# handheld-oriented kernel-rakuos-deck variants, for the ISA level and
# channel CI builds this image for (see kernels.sh).
source "$(dirname "$(readlink -f "$0")")/kernels.sh"

# shellcheck disable=SC2046 # one word per package
rum remove -y $(kernel_subpkgs "${BASE_KERNEL_PKGS[@]}")

# The removed kernels' directories can still hold files no package owns
# (the anti-cheat kernel's vmlinuz.alternate, the initramfs images).
rm -rf /boot/* /usr/lib/modules/* /lib/modules/*

# shellcheck disable=SC2046 # one word per package
rum install -y $(kernel_subpkgs "${KERNEL_PKGS[@]}")

# protected-packages.txt comes from rakuos-base, whose post-build.sh listed
# the kernels it installed. Those were just swapped out: drop them from the
# list and protect the deck kernels instead.
PROTECTED_FILE="/usr/share/rakuos/protected-packages.txt"
for pkg in "${BASE_KERNEL_PKGS[@]}"; do
    sed -i -E "/^[[:space:]]*${pkg}(-devel-matched)?[[:space:]]*$/d" "$PROTECTED_FILE"
done
cat >> "$PROTECTED_FILE" << EOF

# Deck kernels (from rakuos-gamescope/build_files/build.sh)
${KERNEL_PKG}
${KERNEL_PKG}-devel-matched
${KERNEL_AC_PKG}
${KERNEL_AC_PKG}-devel-matched
EOF
for pkg in "${KERNEL_PKGS[@]}"; do
    grep -qx "${pkg}" "$PROTECTED_FILE" \
        || { echo "ERROR: ${pkg} missing from $PROTECTED_FILE"; exit 1; }
done

# depmod/dracut for the deck kernels happen in drivers.sh, after the kmod
# swap and kernel signing so each initramfs is built from the final, signed
# module set (same order rakuos-base uses for its own kernels).

## Install packages
# Fixme: remove --allowerasing
rum install -y --skip-broken --skip-unavailable akonadi-server \
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
