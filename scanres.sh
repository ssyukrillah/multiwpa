#!/bin/bash
for DEV in `iw dev|grep 'Interface'|sed 's/.*Interface //'|grep -v 'wlan.mon$'|sort -n`;do
 echo $DEV
 wpa_cli -i $DEV "scan_result"
done
#|cut -f5|sort -u
