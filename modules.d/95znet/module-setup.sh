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
    inst_hook pre-trigger 30 "$moddir/parse-znet.sh"
    inst_multiple /sbin/chzdev
}
