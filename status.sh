#!/bin/bash

for DEV in `iw dev|grep 'Interface'|sed 's/.*Interface //'|grep -v 'wlan.mon$'`;do
 echo $DEV
 wpa_cli -i $DEV status
 echo
done
