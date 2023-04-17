#!/bin/sh
# livenetroot - fetch a live image from the network and run it

type getarg > /dev/null 2>&1 || . /lib/dracut-lib.sh

. /lib/url-lib.sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin
RETRIES=${RETRIES:-100}
SLEEP=${SLEEP:-5}

[ -e /tmp/livenet.downloaded ] && exit 0

# args get passed from 40network/netroot
netroot="$2"
liveurl="${netroot#livenet:}"
info "fetching $liveurl"

if getargbool 0 'rd.writable.fsimg'; then

    let memsize=$(($(sed -n 's/MemTotal: *\([[:digit:]]*\).*/\1/p' /proc/meminfo) / 1024))
    let imgsize=$(($(curl -sI "$liveurl" | sed -n 's/Content-Length: *\([[:digit:]]*\).*/\1/p') / (1024 * 1024)))

    if [ $((memsize - $imgsize)) -lt 512 ]; then
        sed -i "N;/and attach it to a bug report./s/echo$/echo\n\
        echo \n\
        echo 'Warning!!!'\n\
        echo 'The memory size of your system is too small for this live image.'\n\
        echo 'Expect killed processes due to out of memory conditions.'\n\
        echo \n\ " /usr/bin/dracut-emergency

        emergency_shell
    fi
fi

imgfile=
#retry until the imgfile is populated with data or the max retries
i=1
while [ "$i" -le "$RETRIES" ]; do
    imgfile=$(fetch_url "$liveurl")

    # shellcheck disable=SC2181
    if [ $? != 0 ]; then
        warn "failed to download live image: error $?"
        imgfile=
    fi

    if [ -n "$imgfile" -a -s "$imgfile" ]; then
        break
    else
        if [ $i -ge "$RETRIES" ]; then
            warn "failed to download live image after $i attempts."
            exit 1
        fi

        sleep "$SLEEP"
    fi

    i=$((i + 1))
done > /tmp/livenet.downloaded

# TODO: couldn't dmsquash-live-root handle this?
if [ "${imgfile##*.}" = "iso" ]; then
    root=$(losetup -f)
    losetup "$root" "$imgfile"
else
    root=$imgfile
fi

exec /sbin/dmsquash-live-root "$root"
