#!/bin/bash

for znet in $(getargs rd.znet -d 'rd_ZNET='); do
    IFS=, read -r znet_drv znet_sc0 znet_sc1 znet_sc2 znet_options <<< "$znet"
    if [ -z "$znet_drv" ] || [ -z "$znet_sc0" ] || [ -z "$znet_sc1" ] || [ -z "$znet_sc2" ] ; then
        warn "Invalid arguments for rd.znet="
    else
	warn "+ chzdev --persistent --enable $znet_drv $znet_sc0:$znet_sc1:$znet_sc2 $znet_options"
	chzdev --persistent --enable --force --yes --no-root-update --no-settle $znet_drv $znet_sc0:$znet_sc1:$znet_sc2 $znet_options
    fi
done

