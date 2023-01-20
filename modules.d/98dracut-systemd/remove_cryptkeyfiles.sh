#!/bin/sh

if [ -f /etc/crypttab ]; then
   while read -r _mapper _ _keyfile _o || [ -n "$_mapper" ]; do
        [[ $_mapper = \#* ]] && continue
        [[ $_o =~ x-initrd.attach ]] || continue
        # select entries with password files
        [[ -f $_keyfile ]] || _keyfile=${_keyfile%:*}
        [[ -f $_keyfile ]] || _keyfile=/run/cryptsetup-keys.d/$_mapper.key
        [[ -f $_keyfile ]] || _keyfile=/etc/cryptsetup-keys.d/$_mapper.key
        [[ $keyfiles =~ $_keyfile ]] || keyfiles+="$_keyfile "
   done < /etc/crypttab

   if [[ -n $keyfiles ]]; then
        sed -i "N;/and attach it to a bug report./s/echo$/echo \n\
        echo 'PLEASE NOTE:'\n\
        echo 'The keyfiles for automatic decryption of the filesystems are removed from the'\n\
        echo 'emergency shell due to security constraints.'\n\
        echo 'Use the --keep-cryptkeyfiles parameter at initrd creation time to suppress this'\n\
        echo 'behaviour.'\n\
        echo ''\n/" /bin/dracut-emergency
    fi

    for file in $keyfiles; do
        _keyf+="    rm -f $file\n"
    done
    sed -i "s#^.*sulogin -e#$_keyf    exec sulogin -e#" /bin/dracut-emergency
fi
