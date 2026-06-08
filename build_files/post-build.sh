#!/bin/bash

set -ouex pipefail

# ── SELinux: clear leftover semodule transaction before commit ────────────────
# A package %post runs `semodule` during the build; an uncommitted transaction
# leaves a half-written sandbox at /etc/selinux/targeted/tmp (it copies the whole
# store, incl. the base `bind` module, in there). That gets baked into the image,
# then ostree's deploy-time `semodule -N --refresh` tries to use it and dies
# (".../tmp/modules/100/bind/lang_ext: No such file"), failing
# ostree-finalize-staged. Fully rebuild+commit the store, then drop the sandbox.
if command -v semodule >/dev/null 2>&1; then
    rm -rf /etc/selinux/targeted/tmp /var/lib/selinux/targeted/tmp 2>/dev/null || true
    semodule -B -N 2>/dev/null || true   # rebuild binary policy, no kernel reload
    rm -rf /etc/selinux/targeted/tmp /var/lib/selinux/targeted/tmp 2>/dev/null || true
fi
