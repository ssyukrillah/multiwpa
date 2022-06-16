#!/bin/bash
while true;do
#./wlan01.sh >> /var/log/mylog/wlan01.log
./nodup.sh >> /var/log/mylog/nodup.log
sleep 30
./multigw.sh >> /var/log/mylog/multigw.log
sleep 30
done

