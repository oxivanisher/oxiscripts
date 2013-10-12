#!/bin/bash

(
        echo -n `uptime | grep days | sed 's/.*up \([0-9]*\) day.*/\1\/10+/'`
        echo -n `cat /proc/cpuinfo | grep MHz | awk '{print $4"/30 +";}'`
        echo -n `free | grep '^Mem' | awk '{print $3"/1024/3+"}'`
        echo -n `df -P -k -x nfs | grep -v 1k | awk '{if ($1 ~ "/dev/(scsi|sd)"){ s+= $2} s+= $2;} END {print s/1024/50"/15+70";}#'`
        echo ""
) | bc | sed 's/\(.$\)/.\1cm/'
