#!/bin/bash

set -ouex pipefail

# The deck kernels build.sh installed (both variants; see kernels.sh).
# RAKUOS_ISA_LEVEL and RAKUOS_STAGING persist as image ENV, so they're
# already set here.
source "$(dirname "$(readlink -f "$0")")/kernels.sh"

# Prebuilt, RakuOS-signed kernel modules (signed-kmods repo) for the deck
# kernels: rakuos-kmod-<name>-deck, or -deck-staging for the staging
# kernels. Each package carries the modules for both deck kernel variants.
# Nothing is compiled or signed here any more.
KMOD_SUFFIX=""
if [ "${RAKUOS_STAGING:-0}" = "1" ]; then
    KMOD_SUFFIX="-staging"
fi

# The installed deck kernels' releases, default first.
load_kernel_releases

# The base image ships the modules for kernel-rakuos (rakuos-kmod-<name>);
# this image swapped in the kernel-rakuos-deck kernels, so install the deck builds and
# drop the base ones. The deck packages provide the same <name>-kmod the
# companion packages (broadcom-wl, v4l2loopback, xone, ...) need. Same list
# as KMODS in rakuos-base's drivers.sh (everything but NVIDIA, VirtualBox,
# openrazer and mediatek-mt7927).
#
# Both flavors provide akmod-<name>/dkms-<name> and conflict with it, so a
# deck package can't go in while its base package is still installed. Drop
# the base packages first, without their dependents (the companions'
# <name>-kmod requirement is met again by the deck packages right after).
DECK_KMODS=(
    wl v4l2loopback
)
BASE_KMOD_PKGS=()
for kmod in "${DECK_KMODS[@]}"; do
    if rpm -q "rakuos-kmod-${kmod}${KMOD_SUFFIX}" >/dev/null 2>&1; then
        BASE_KMOD_PKGS+=("rakuos-kmod-${kmod}${KMOD_SUFFIX}")
    fi
done
if [ "${#BASE_KMOD_PKGS[@]}" -gt 0 ]; then
    rpm -e --nodeps "${BASE_KMOD_PKGS[@]}"
fi
rum install -y sbsigntools $(printf "rakuos-kmod-%s-deck${KMOD_SUFFIX} " "${DECK_KMODS[@]}")

# The signed-kmods packages carry modules only for the kernels that were
# current when they were built. One that predates these kernels installs
# without complaint and ships nothing loadable, so fail the build instead.
for pkg in $(printf "rakuos-kmod-%s-deck${KMOD_SUFFIX} " "${DECK_KMODS[@]}"); do
    for kver in "${KERNEL_RELEASES[@]}"; do
        grep -q "^/usr/lib/modules/${kver}/" < <(rpm -ql "$pkg") || {
            echo "ERROR: $(rpm -q "$pkg") has no modules for ${kver}; rebuild signed-kmods"
            exit 1
        }
    done
done

# Out-of-tree modules (rakuos-kmod-*-deck) arrive already signed with the
# RakuOS key by the signed-kmods CI, so there's no module signing step here.

# Sign each kernel with the MOK key and build its initramfs from the final,
# signed module set, then leave only the default kernel's vmlinuz where
# bootc looks (kernels.sh).
for kver in "${KERNEL_RELEASES[@]}"; do
    sign_kernel "${kver}"
    build_initramfs "${kver}"
done
stash_alternate_kernels

rm -rf /var/lib/dkms /var/cache/akmods
