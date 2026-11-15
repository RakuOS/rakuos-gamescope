# shellcheck shell=bash
# kernels.sh: the kernels this image ships. Sourced by build.sh and
# drivers.sh, so they agree on them. The deck counterpart of rakuos-base's
# build_files/kernels.sh: keep the two in step.
#
# The image it's built on ships both kernel-rakuos variants; this one swaps
# them for both kernel-rakuos-deck variants for its x86-64 ISA level
# (RAKUOS_ISA_LEVEL = v2, v3 or v4), from the kernel's -staging builds on the
# staging branch (RAKUOS_STAGING=1):
#
#   kernel-rakuos-deck-<isa>[-staging]     the normal kernel, booted by default
#   kernel-rakuos-deck-ac-<isa>[-staging]  the anti-cheat (Easy Anti-Cheat) kernel
#
# bootc and ostree boot the one /usr/lib/modules/<kver> that has a vmlinuz,
# and bootc refuses an image that has more than one. So only the default
# kernel keeps its vmlinuz there. The other kernel's modules and initramfs
# stay in its own /usr/lib/modules/<kver>, and its (signed) image is kept
# beside them as vmlinuz.alternate, ready for a second boot entry.

RAKUOS_ISA_LEVEL="${RAKUOS_ISA_LEVEL:-v2}"
case "${RAKUOS_ISA_LEVEL}" in
    v2|v3|v4) ;;
    *) echo "Unknown RAKUOS_ISA_LEVEL '${RAKUOS_ISA_LEVEL}' (want v2, v3 or v4)" >&2; exit 1 ;;
esac
KERNEL_SUFFIX=""
if [ "${RAKUOS_STAGING:-0}" = "1" ]; then
    KERNEL_SUFFIX="-staging"
fi

# The base image's kernels, which this image removes.
BASE_KERNEL_PKGS=("kernel-rakuos-${RAKUOS_ISA_LEVEL}${KERNEL_SUFFIX}" "kernel-rakuos-ac-${RAKUOS_ISA_LEVEL}${KERNEL_SUFFIX}")

# This image's kernels, the default first.
KERNEL_PKG="kernel-rakuos-deck-${RAKUOS_ISA_LEVEL}${KERNEL_SUFFIX}"
KERNEL_AC_PKG="kernel-rakuos-deck-ac-${RAKUOS_ISA_LEVEL}${KERNEL_SUFFIX}"
KERNEL_PKGS=("${KERNEL_PKG}" "${KERNEL_AC_PKG}")
ALT_VMLINUZ="vmlinuz.alternate"

# kernel_subpkgs PKG...: each kernel with its -core, -modules, -devel and
# -devel-matched.
kernel_subpkgs() {
    local p
    for p in "$@"; do
        echo "${p} ${p}-core ${p}-modules ${p}-devel ${p}-devel-matched"
    done
}

# kernel_release PKG: the kernel's release (uname -r), its /usr/lib/modules
# dir. Fails the build if the kernel isn't installed.
kernel_release() {
    local kver
    kver=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' "$1") \
        || { echo "ERROR: $1 isn't installed" >&2; exit 1; }
    echo "${kver}"
}

# Sets KERNEL_RELEASES to the releases of this image's kernels, default first.
load_kernel_releases() {
    local p
    KERNEL_RELEASES=()
    for p in "${KERNEL_PKGS[@]}"; do
        KERNEL_RELEASES+=("$(kernel_release "${p}")")
    done
}

# kernel_vmlinuz KVER: the kernel image, under either name.
kernel_vmlinuz() {
    local dir="/usr/lib/modules/$1"
    if [ -f "${dir}/vmlinuz" ]; then
        echo "${dir}/vmlinuz"
    else
        echo "${dir}/${ALT_VMLINUZ}"
    fi
}

# sign_kernel KVER: signs the kernel image with the RakuOS Secure Boot key,
# when the build has it (the mok_key secret).
sign_kernel() {
    local kver="$1" vmlinuz key="/run/secrets/mok_key" cert_der="/usr/share/rakuos/sb_pubkey.der" cert_pem
    vmlinuz=$(kernel_vmlinuz "${kver}")
    if [[ -f "${key}" ]] && [[ -f "${vmlinuz}" ]] && [[ -f "${cert_der}" ]]; then
        echo "Signing kernel ${kver}..."
        cert_pem=$(mktemp /tmp/MOK.XXXXXX.crt)
        openssl x509 -in "${cert_der}" -inform DER -out "${cert_pem}" -outform PEM
        sbsign --key "${key}" --cert "${cert_pem}" --output "${vmlinuz}.signed" "${vmlinuz}"
        mv "${vmlinuz}.signed" "${vmlinuz}"
        rm -f "${cert_pem}"
        echo "Kernel ${kver} signed."
    else
        echo "MOK key or ${vmlinuz} not available — skipping signing kernel ${kver}."
    fi
}

# build_initramfs KVER: module dependencies and the initramfs for one kernel.
build_initramfs() {
    local kver="$1"
    depmod "${kver}"
    /usr/bin/dracut --no-hostonly --kver "${kver}" --reproducible --zstd -v \
        --add ostree --add fido2 --add rakuos-overlay --add rakuos-groups --omit selinux \
        -f "/usr/lib/modules/${kver}/initramfs.img"
    chmod 0600 "/usr/lib/modules/${kver}/initramfs.img"
}

# Moves every kernel image but the default one's to vmlinuz.alternate, then
# checks the default kernel is the only one bootc and ostree can see.
stash_alternate_kernels() {
    local default kver vmlinuzes
    load_kernel_releases
    default="${KERNEL_RELEASES[0]}"
    for kver in "${KERNEL_RELEASES[@]}"; do
        [ "${kver}" = "${default}" ] && continue
        if [ -f "/usr/lib/modules/${kver}/vmlinuz" ]; then
            mv "/usr/lib/modules/${kver}/vmlinuz" "/usr/lib/modules/${kver}/${ALT_VMLINUZ}"
        fi
        [ -f "/usr/lib/modules/${kver}/${ALT_VMLINUZ}" ] \
            || { echo "ERROR: kernel ${kver} has no image" >&2; exit 1; }
    done
    vmlinuzes=$(ls /usr/lib/modules/*/vmlinuz)
    [ "${vmlinuzes}" = "/usr/lib/modules/${default}/vmlinuz" ] \
        || { echo "ERROR: want only /usr/lib/modules/${default}/vmlinuz, found: ${vmlinuzes}" >&2; exit 1; }
}
