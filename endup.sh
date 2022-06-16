#!/bin/bash
echo "Start ENDUP:$(date)"
if [ ! -f /tmp/nodup.cnt ];then echo 1 > /tmp/nodup.cnt;fi
if [ $(cat /tmp/nodup.cnt) -gt 0 ];then echo $(($(cat /tmp/nodup.cnt) - 1 )) > /tmp/nodup.cnt;fi

echo "counter : $(cat /tmp/nodup.cnt)"

if [ $(cat /tmp/nodup.cnt) -le 0 ];then
 for DEV in `iw dev|grep 'Interface'|sed 's/.*Interface //'|grep -v 'wlan.mon$'`;do
  echo -n "$DEV : "
  if [ $(ls /tmp/nodup.sh.wlan?.$DEV.old|wc -l) -gt 0 ];then
   for DUP in `sort -nu /tmp/nodup.sh.wlan?.$DEV.old`;do
    echo "Enabling $DUP on $DEV"
    echo -e "enable_network $DUP \n quit" | wpa_cli -i $DEV
   done
  fi
 done
fi
echo "End ENDUP:$(date)"
