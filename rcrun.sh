#!/bin/bash
cd "$(dirname $0)"
if [ ! -d /var/log/mylog ];then mkdir /var/log/mylog;fi
if [ ! -f /tmp/wpa_supplicant.conf ];then touch /tmp/wpa_supplicant.conf;fi
P=-1

#if [ -f loop.sh ];then
# if (pgrep -f "loop.sh" > /dev/null);then
#  false
# else
#  ./loop.sh > /var/log/mylog/loop.log &
# fi
#fi



while true;do
echo 0 > /tmp/counter
for DEV in `iw dev|grep 'Interface'|sed 's/.*Interface //'|grep -v 'wlan.mon$'`;do
 if (pgrep -f "autowpa2.sh $DEV" > /dev/null);then
  false
 else
  if (pgrep -f "dhclient.*$DEV" > /dev/null);then
   dhclient -x $DEV
  fi
  pkill -f "dhclient.*$DEV"
  pkill -f "wpa_supplicant.*$DEV"
  echo "Run autowpa $DEV"
  ./autowpa2.sh $DEV > /var/log/mylog/autowpa2.$DEV.log &
 fi
done

if [ -f loop.sh ];then
 if (pgrep -f "loop.sh" > /dev/null);then
  false
 else
  echo "Run loop.sh"
  ./loop.sh > /var/log/mylog/loop.log &
 fi
fi

#if [ $P -le -1 ];then P=$(pgrep -fa autowpa2.sh.*wlan\|loop.sh|wc -l);fi

#if [ $P -lt $(pgrep -fa autowpa2.sh.*wlan\|loop.sh|wc -l) ];then
# P=$(pgrep -fa autowpa2.sh.*wlan\|loop.sh|wc -l)
#fi

echo -n "Sleep until any process has killed: "
while [ $(iw dev|grep 'Interface'|sed 's/.*Interface //'|grep -v 'wlan.mon$'|wc -l) -eq $(pgrep -fa "autowpa2.sh wlan?"|wc -l) ] && \
	[ "$(pgrep -fa loop.sh)" != "" ];do
#[ $P -ge $(pgrep -fa autowpa2.sh.*wlan\|loop.sh|wc -l) ];do
 HIT=10
 until [ $HIT -le 0 ];do
  HIT=$(($HIT-1))
  echo -en "$HIT\x8"
  sleep 1
 done
 echo -n "*"
done

#sleep $((60*15))

done
