#!/bin/bash

# called by dracut
check() {
    [[ $mount_needs ]] && return 1

    return 0
}

# called by dracut
depends() {
    echo "systemd-initrd"
    return 0
}

installkernel() {
    return 0
}

# called by dracut
install() {
    inst_script "$moddir/dracut-emergency.sh" /bin/dracut-emergency
    inst_simple "$moddir/emergency.service" "${systemdsystemunitdir}"/emergency.service
    inst_simple "$moddir/dracut-emergency.service" "${systemdsystemunitdir}"/dracut-emergency.service
    inst_simple "$moddir/emergency.service" "${systemdsystemunitdir}"/rescue.service

    ln_r "${systemdsystemunitdir}/initrd.target" "${systemdsystemunitdir}/default.target"

    inst_script "$moddir/dracut-cmdline.sh" /bin/dracut-cmdline
    inst_script "$moddir/dracut-cmdline-ask.sh" /bin/dracut-cmdline-ask
    inst_script "$moddir/dracut-pre-udev.sh" /bin/dracut-pre-udev
    inst_script "$moddir/dracut-pre-trigger.sh" /bin/dracut-pre-trigger
    inst_script "$moddir/dracut-initqueue.sh" /bin/dracut-initqueue
    inst_script "$moddir/dracut-pre-mount.sh" /bin/dracut-pre-mount
    inst_script "$moddir/dracut-mount.sh" /bin/dracut-mount
    inst_script "$moddir/dracut-pre-pivot.sh" /bin/dracut-pre-pivot

    inst_script "$moddir/rootfs-generator.sh" "$systemdutildir"/system-generators/dracut-rootfs-generator

    for i in \
        dracut-cmdline.service \
        dracut-cmdline-ask.service \
        dracut-initqueue.service \
        dracut-mount.service \
        dracut-pre-mount.service \
        dracut-pre-pivot.service \
        dracut-pre-trigger.service \
        dracut-pre-udev.service; do
        inst_simple "$moddir/${i}" "$systemdsystemunitdir/${i}"
        $SYSTEMCTL -q --root "$initdir" add-wants initrd.target "$i"
    done

    inst_simple "$moddir/dracut-tmpfiles.conf" "$tmpfilesdir/dracut-tmpfiles.conf"

    inst_multiple sulogin

    if [ -f "$dracutsysrootdir"/etc/crypttab ]; then
        remove_cryptkeyfiles
    fi
}

remove_cryptkeyfiles() {
    if [ -z "$keep_cryptkeyfiles" ]; then
       while read -r _mapper _ _keyfile _o || [ -n "$_mapper" ]; do
            [[ $_mapper = \#* ]] && continue
            [[ $_o =~ x-initrd.attach ]] || continue
            # select entries with password files
            [[ -f $_keyfile ]] || _keyfile=${_keyfile%:*}
            [[ -f $_keyfile ]] || _keyfile=/run/cryptsetup-keys.d/$_mapper.key
            [[ -f $_keyfile ]] || _keyfile=/etc/cryptsetup-keys.d/$_mapper.key
            [[ $keyfiles =~ $_keyfile ]] || keyfiles+="$_keyfile "
       done < "$dracutsysrootdir"/etc/crypttab

       if [[ -n $keyfiles ]]; then
            sed -i "N;/and attach it to a bug report./s/echo$/echo \n\
            echo 'PLEASE NOTE:'\n\
            echo 'The keyfiles for automatic decryption of the filesystems are removed from the'\n\
            echo 'emergency shell due to security constraints.'\n\
            echo 'Use the --keep-cryptkeyfiles parameter at initrd creation time to suppress this'\n\
            echo 'behaviour.'\n\
            echo ''\n/" $initdir/bin/dracut-emergency
        fi

        for file in $keyfiles; do
            _keyf+="    rm -f $file\n"
        done
        sed -i "s#^.*sulogin -e#$_keyf    exec sulogin -e#" $initdir/bin/dracut-emergency
    fi
}
