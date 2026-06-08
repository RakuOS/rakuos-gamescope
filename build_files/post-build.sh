#!/bin/bash

set -ouex pipefail

# ── SELinux: regenerate the policy module store before commit ─────────────────
# A package transaction in build.sh leaves a base policy module dir missing its
# lang_ext metadata (observed: active/modules/100/bind/lang_ext absent). Any
# `semodule` rebuild then fails with "Unable to open bind module lang ext file"
# — including ostree's deploy-time `semodule -N --refresh`, which bricks the
# deploy. Documented remedy for a corrupt store: drop the stale sandbox,
# reinstall the policy package to lay down a clean store, then rebuild the
# binary policy. No `|| true`: if it still can't reconcile, fail the build loudly.
if command -v semodule >/dev/null 2>&1; then
    rm -rf /etc/selinux/targeted/tmp /var/lib/selinux/targeted/tmp
    DNF=dnf5.real; command -v dnf5.real >/dev/null 2>&1 || DNF=dnf5  # dnf5 is wrapped in our images
    "$DNF" -y reinstall selinux-policy-targeted
    semodule -B
    rm -rf /etc/selinux/targeted/tmp /var/lib/selinux/targeted/tmp
fi
