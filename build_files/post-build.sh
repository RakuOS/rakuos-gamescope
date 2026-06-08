#!/bin/bash

set -ouex pipefail

# ── SELinux: rebuild the policy module store before commit ────────────────────
# Packages like NetworkManager-ssh-gnome pull in an SELinux subpackage whose
# %post runs `semodule -i`. That transaction can leave the module store in a
# state ostree's deploy-time `semodule -N --refresh` can't rebuild — e.g.
# ".../active/modules/100/bind/lang_ext: No such file" — which fails
# ostree-finalize-staged and bricks the deploy.
#
# Rebuild + commit the store HERE so the committed image is consistent and the
# deploy-time refresh is a clean no-op. No `|| true`: if the store can't
# reconcile we want the BUILD to fail loudly (debuggable) rather than ship an
# image that fails on deploy. (SELinux is disabled in the build container, so
# `semodule -B` rebuilds the store and skips the kernel reload, exiting 0.)
if command -v semodule >/dev/null 2>&1; then
    rm -rf /etc/selinux/targeted/tmp /var/lib/selinux/targeted/tmp
    semodule -B
    rm -rf /etc/selinux/targeted/tmp /var/lib/selinux/targeted/tmp
fi
