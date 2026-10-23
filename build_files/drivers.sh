#!/bin/bash

set -ouex pipefail

# Same ISA-level/staging switch as build.sh (RAKUOS_ISA_LEVEL and
# RAKUOS_STAGING persist as image ENV from that layer, so they're already
# set here).
ISA_LEVEL="${RAKUOS_ISA_LEVEL:-v2}"
KERNEL_DECK_PKG="kernel-rakuos-deck-${ISA_LEVEL}"
if [ "${RAKUOS_STAGING:-0}" = "1" ]; then
    KERNEL_DECK_PKG="${KERNEL_DECK_PKG}-staging"
fi

# Prebuilt, RakuOS-signed kernel modules (signed-kmods repo) for the deck
# kernel: rakuos-kmod-<name>-deck, or -deck-staging for the staging kernel.
# Nothing is compiled or signed here any more.
KMOD_SUFFIX=""
if [ "${RAKUOS_STAGING:-0}" = "1" ]; then
    KMOD_SUFFIX="-staging"
fi

# Determine the installed kernel version (kernel-rakuos-deck-<isa>, installed
# by build.sh, including its -devel/-devel-matched subpackages).
QUALIFIED_KERNEL=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' ${KERNEL_DECK_PKG})

# The base image ships the modules for kernel-rakuos (rakuos-kmod-<name>);
# this image swapped in kernel-rakuos-deck, so install the deck builds and
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
    xone xpadneo xpad-noone
    hid-fanatecff hid-tmff2 t150-driver new-lg4ff logitech-trueforce
    ayaneo-leds
    sc0710
    nct6687d ryzen_smu zenergy
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
# current when they were built. One that predates this kernel installs
# without complaint and ships nothing loadable, so fail the build instead.
for pkg in $(printf "rakuos-kmod-%s-deck${KMOD_SUFFIX} " "${DECK_KMODS[@]}"); do
    grep -q "^/usr/lib/modules/${QUALIFIED_KERNEL}/" < <(rpm -ql "$pkg") || {
        echo "ERROR: $(rpm -q "$pkg") has no modules for ${QUALIFIED_KERNEL}; rebuild signed-kmods"
        exit 1
    }
done

# Out-of-tree modules (rakuos-kmod-*-deck) arrive already signed with the
# RakuOS key by the signed-kmods CI, so there's no module signing step here.

# Sign the kernel vmlinuz with the MOK key
VMLINUZ="/usr/lib/modules/${QUALIFIED_KERNEL}/vmlinuz"
MOK_KEY="/run/secrets/mok_key"
MOK_CERT_DER="/usr/share/rakuos/sb_pubkey.der"
if [[ -f "$MOK_KEY" ]] && [[ -f "$VMLINUZ" ]] && [[ -f "$MOK_CERT_DER" ]]; then
    echo "Signing kernel ${QUALIFIED_KERNEL}..."
    MOK_CERT_PEM=$(mktemp /tmp/MOK.XXXXXX.crt)
    openssl x509 -in "$MOK_CERT_DER" -inform DER -out "$MOK_CERT_PEM" -outform PEM
    sbsign --key "$MOK_KEY" --cert "$MOK_CERT_PEM" \
        --output "${VMLINUZ}.signed" "$VMLINUZ"
    mv "${VMLINUZ}.signed" "$VMLINUZ"
    rm -f "$MOK_CERT_PEM"
    echo "Kernel signed."
else
    echo "MOK key or vmlinuz not available — skipping kernel signing."
fi

# Build the initramfs from the final, signed module set.
depmod "$QUALIFIED_KERNEL"
/usr/bin/dracut --no-hostonly --kver "$QUALIFIED_KERNEL" --reproducible --zstd -v \
    --add ostree --add fido2 --add rakuos-overlay --add rakuos-groups --omit selinux -f "/usr/lib/modules/$QUALIFIED_KERNEL/initramfs.img"
chmod 0600 /usr/lib/modules/"$QUALIFIED_KERNEL"/initramfs.img

rm -rf /var/lib/dkms /var/cache/akmods
