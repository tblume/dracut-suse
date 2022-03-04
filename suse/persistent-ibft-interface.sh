#! /bin/bash

#set -x

RULES="70-persistent-net.rules"
export LC_ALL=C

error() { echo "$@" >&2; }

usage () {
    [[ $1 = '-n' ]] && cmd=echo || cmd=error

    $cmd "usage: ${0##*/} [options]"
    $cmd ""
    $cmd "!·····Update persistent device naming scheme for iBFT devices"
    $cmd "!·····Update 70-persistent-net.rules to set the persistent name of the iBFT"
    $cmd "!·····devices to ibftX."
    $cmd "!·····Add an ifname= parameter to the dracut config to bind the ibftX name"
    $cmd "!·····to a mac address."
    $cmd ""
    $cmd "!·····options:"
    $cmd "!·····-h!·····!·······!·······This help screen."

    [[ $1 = '-n' ]] && exit 0
    exit 1
}

getiface() {
    # Enforce exit on error
    trap 'echo "$0: ERROR in $BASH_COMMAND" >&2; exit 1' ERR

    # Cleanup on exit
    CLEANUP=':'
    trap 'eval "$CLEANUP"' 0

    # Make sure a valid interface name is passed
    [[ $# == 1 && $1 && -d "/sys/class/net/$1" ]] || {
        echo "Usage: $0 interfacename" >&2
        exit 1
    }
    IFACE=$1

    # disable udev event processing while modified rules are in place
    udevadm control -s

    # re-enable udev event processing on exit
    CLEANUP="udevadm control -S; $CLEANUP"

    TMPDIR="$(mktemp -d /tmp/iface-XXXXXX)"
    [ -d "$TMPDIR" ]
    CLEANUP="rm -rf $TMPDIR; $CLEANUP"

    # create a backup and make sure it's restored on exit
    cp -a "/etc/udev/rules.d/$RULES" "$TMPDIR"
    CLEANUP='cp -a "$TMPDIR/$RULES" /etc/udev/rules.d; '"$CLEANUP"

    # Override the open-iscsi ibft rule in /run/udev/rules.d
    [[ ! -e /etc/udev/rules.d/79-ibft.rules ]]
    ln -sf /dev/null /etc/udev/rules.d/79-ibft.rules
    CLEANUP='rm -f /etc/udev/rules.d/79-ibft.rules; '"$CLEANUP"

    # Remove the match for KERNEL=="eth*" from 70-persistent-net.rules
    # This way the rules will be applied also for "ibft0"
    sed -i 's/KERNEL=="eth\*",//' "/etc/udev/rules.d/$RULES"

    # Run "udevadm test" and pick the last "NAME" directive executed
    NAME="$(udevadm test "/sys/class/net/$IFACE" 2>&1 | sed -En "s/.* NAME '([^ ']*).*/\\1/p" | tail -n1)"

    echo $NAME
}

while (($# > 0)); do
    case ${1%%=*} in
        -h|--help) usage -n;;
        *) usage;;
    esac
done

for IBFTDEV in $(iscsiadm -m fw | sed -n '/iface.net_ifacename/s/iface.net_ifacename = //p' | uniq); do
    PERSISTENTNAME=$(getiface $IBFTDEV)
    if [[ "$PERSISTENTNAME" =~ "eth" ]] && [[ "$PERSISTENTNAME" != "$IBFTDEV" ]]; then
        echo "renaming $PERSISTENTNAME to $IBFTDEV"
        sed -i "s/NAME=\"$PERSISTENTNAME\"/NAME=\"$IBFTDEV\"/" "/etc/udev/rules.d/$RULES"
    fi

    IBFTMAC=$(ip link show $IBFTDEV | sed -n 's/.*ether \([[:graph:]]*\) .*/\1/p')
    IBFTPARAMS+=" ifname=$IBFTDEV:$IBFTMAC"
done

# If nothing was set, error out
[[ "$IBFTPARAMS" ]] || exit 1

echo "setting persistent network device naming to: $IBFTPARAMS"
echo kernel_cmdline=\"$IBFTPARAMS\" > /etc/dracut.conf.d/55-persistent-ibft-naming.conf
dracut -f

exit 0

