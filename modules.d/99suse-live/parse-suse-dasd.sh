#!/bin/bash

for dasd in $(getargs rd.dasd -d 'rd_DASD='); do
    dasd_drv=dasd
    IFS=, read -r dasd_sc0 dasd_options <<< "$dasd"
    if [ -z "$dasd_sc0" ]; then
        warn "Invalid arguments for rd.dasd="
    else
	warn "+ chzdev --persistent --enable $dasd_drv $dasd_sc0 $dasd_options"
	chzdev --persistent --enable --force --yes --no-root-update --no-settle $dasd_drv $dasd_sc0 $dasd_options
    fi
done

