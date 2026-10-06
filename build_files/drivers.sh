#!/bin/bash

set -ouex pipefail

# Same ISA-level/staging switch as build.sh (RAKUOS_ISA_LEVEL and
# RAKUOS_STAGING persist as image ENV from that layer, so they're already
# set here).
ISA_LEVEL="${RAKUOS_ISA_LEVEL:-v2}"
STAGING_TAG=""
if [ "${RAKUOS_STAGING:-0}" = "1" ]; then
    STAGING_TAG="-staging"
fi
KERNEL_DECK_PKG="kernel-p03-raku-deck${STAGING_TAG}-${ISA_LEVEL}"

# Determine the installed kernel version (kernel-p03-raku-deck-<isa>, installed
# by build.sh, including its -devel/-devel-matched subpackages).
QUALIFIED_KERNEL=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' ${KERNEL_DECK_PKG})

rum install -y akmods sbsigntools

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Build akmod packages for the installed kernel-deck kernel.
# akmods installs the resulting kmod RPM so the .ko lands in
# /usr/lib/modules/$QUALIFIED_KERNEL/extra/ where the signing loop picks it up.
echo "Building akmods for kernel ${QUALIFIED_KERNEL}..."
akmods --kernels "$QUALIFIED_KERNEL" --rebuild
# Install any built kmod RPMs from the cache
find /var/cache/akmods -name "*.rpm" ! -name "*src.rpm" | xargs -r rum install -y

# Sign all extra kernel modules with the MOK key (skipped silently if the
# key isn't present, e.g. forks without access to the MOK Secure File).
MOK_KEY="/run/secrets/mok_key"
MOK_CERT="/usr/share/rakuos/sb_pubkey.der"
SIGN_FILE="/usr/src/kernels/${QUALIFIED_KERNEL}/scripts/sign-file"
if [[ -f "$MOK_KEY" ]] && [[ -f "$SIGN_FILE" ]]; then
    echo "Signing all extra kernel modules..."
    while IFS= read -r ko; do
        case "$ko" in
            *.ko.xz)
                bare="${ko%.xz}"
                xz -dk "$ko"
                "$SIGN_FILE" sha256 "$MOK_KEY" "$MOK_CERT" "$bare"
                xz -f "$bare"
                ;;
            *.ko.zst)
                bare="${ko%.zst}"
                zstd -dq "$ko" -o "$bare"
                "$SIGN_FILE" sha256 "$MOK_KEY" "$MOK_CERT" "$bare"
                zstd -qf "$bare" -o "$ko"
                rm -f "$bare"
                ;;
            *.ko)
                "$SIGN_FILE" sha256 "$MOK_KEY" "$MOK_CERT" "$ko"
                ;;
        esac
        echo "  Signed: $(basename "$ko")"
    done < <(find "/usr/lib/modules/${QUALIFIED_KERNEL}/extra" \
        \( -name "*.ko" -o -name "*.ko.xz" -o -name "*.ko.zst" \) 2>/dev/null)
    echo "Module signing complete."
else
    echo "MOK key or sign-file not available — skipping module signing."
fi

# Sign the kernel vmlinuz with the MOK key
VMLINUZ="/usr/lib/modules/${QUALIFIED_KERNEL}/vmlinuz"
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
    --add ostree --add fido2 --add rakuos-overlay -f "/usr/lib/modules/$QUALIFIED_KERNEL/initramfs.img"
chmod 0600 /usr/lib/modules/"$QUALIFIED_KERNEL"/initramfs.img

rm -rf /var/lib/dkms /var/cache/akmods
