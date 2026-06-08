#!/bin/bash

set -ouex pipefail

# ── SELinux: reconcile the policy store ───────────────────────────────────────
# Package %post scriptlets (semodule/semanage) can leave the SELinux policy store
# half-applied/inconsistent during the container build, which makes ostree fail
# to deploy the image. Clear leftover transaction state and rebuild the binary
# policy so policy and module store agree.
if command -v semodule >/dev/null 2>&1; then
    rm -rf /var/lib/selinux/*/tmp /var/lib/selinux/*/active/modules/disabled 2>/dev/null || true
    semodule -B -N 2>/dev/null || semodule -B 2>/dev/null || true   # -N: rebuild, don't reload
fi
