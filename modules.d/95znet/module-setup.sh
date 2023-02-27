#!/bin/bash

# called by dracut
check() {
    arch=${DRACUT_ARCH:-$(uname -m)}
    [ "$arch" = "s390" -o "$arch" = "s390x" ] || return 1

    require_binaries grep sed seq readlink || return 1

    return 0
}

# called by dracut
depends() {
    echo bash
    return 0
}

# called by dracut
installkernel() {
    instmods ctcm lcs qeth qeth_l2 qeth_l3
}

# called by dracut
install() {
    inst_hook cmdline 30 "$moddir/parse-ccw.sh"
    inst_simple "$moddir/ccw_init" /usr/lib/udev/ccw_init
    inst_simple "$moddir/ccw.udev" /etc/udev/rules.d/81-ccw.rules
    inst_rules 81-ccw.rules
    inst_multiple grep sed seq readlink /sbin/chzdev
}
