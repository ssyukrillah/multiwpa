#!/bin/bash
cd "$(dirname $0)"

if [ "$1" == "" ];then
 echo "parameter missing, using $0 [wlan0/wlan1/wlan...]"
 exit
fi

if (/usr/sbin/iw dev | /usr/bin/grep -qs $1);then
 echo -n "|Found $1"
 espeak --stdout "Start on $(echo $1|sed 's/wlan/Wireless lan /')"|aplay -q
else
 echo "$1 NOT FOUND.. EXIT!"
 exit 2
fi

if [ "$1" != "wlan0" ] && [ $(macchanger -s $1|cut -d':' -f2-|cut -d'(' -f1|sed ':a;s/^ //;t a;:b;s/ $//;t b'|sort -u|wc -l) -le 1 ];then
 echo -n "|Init ChgMAC|$1 Down"
 /usr/sbin/ifconfig $1 down
 sleep 1
 echo -n "|Change MAC"
 /usr/bin/macchanger -A $1
 sleep 1
 echo -n "|$1 Up"
 /usr/sbin/ifconfig $1 up
 sleep 1
 echo "|Done"
else
 echo -n "|MAC already Changed"
fi

UPTIME=$(cut -d'.' -f1 /proc/uptime)
RTO=0
NOGW=0
NONET=0
FAIL=0
ROK=0

truncate -s 0 /tmp/nodup.sh.wlan?.$1.old
if [ ! -f /tmp/wpa_supplicant.conf ];then
 echo -e "\nnetwork={\n\tscan_ssid=1\n\tssid=\"Indihome\"\n\tpsk=\"qazxswedcvfr\"\n}" >> /tmp/wpa_supplicant.conf 
fi
if [ ! -f /tmp/wpa_supplicant.$1.md5 ];then md5sum /tmp/wpa_supplicant.conf|cut -d' ' -f1 > /tmp/wpa_supplicant.$1.md5;fi
md5sum $0|cut -d' ' -f1 > /tmp/autowpa.$1.md5

while (/usr/sbin/iw dev | /usr/bin/grep -qs $1) && [ "$(cat /tmp/autowpa.$1.md5)" == "$(md5sum $0|cut -d' ' -f1)" ];do
echo 0 > /tmp/counter
 if (pgrep -f wpa_supplicant.*$1 > /dev/null);then
  echo -n "|wpas:ok"
  if [[ "$(wpa_cli -i $1 status|grep 'wpa_state')" =~ "COMPLETED" ]];then

   #./wlan01.sh >> /var/log/mylog/wlan01.log
   ./nodup.sh >> /var/log/mylog/nodup.log

   if (pgrep -f dhclient.*$1 > /dev/null);then
    if [ ! -f "/tmp/ssid.$1" ];then wpa_cli -i $1 status|grep "^ssid="|sed "s/^ssid=//" > /tmp/ssid.$1;fi
    if [ "$(wpa_cli -i $1 status|grep '^ssid='|sed 's/^ssid=//')" != "$(cat /tmp/ssid.$1)" ];then
     echo -n "|SSID Changed:$(cat /tmp/ssid.$1) -> "
     wpa_cli -i $1 status|grep "^ssid="|sed "s/^ssid=//" > /tmp/ssid.$1
     echo -n $(cat /tmp/ssid.$1)"|kill dhclient:"
     HIT=15
     while (pgrep -f dhclient.*$1 > /dev/null) && [ $HIT -gt 0 ];do
      dhclient -x $1
      pkill -f "dhclient .* $1"
      HIT=$(($HIT-1))
      echo -n $HIT"."
      sleep 1
      echo 0 > /tmp/counter
     done
    else     
     if [ $(ip route|grep default|wc -l) -gt 1 ];then
      ./multigw.sh
     fi
     if (ip route|grep -qs "[default\|nexthop] via .* dev.*$1");then
      NOGW=0
      echo -n -e "\nPING GDNS:"
      while (ping -I $1 -c1 -i1 -W1 8.8.8.8 > /dev/null);do
       echo -n "*"
       ROK=$(($ROK+1))
       if [ $ROK -gt 20 ];then
	echo -n "|wpa scan"
	wpa_cli -i $1 "scan"
	sleep 2
	if [ $(wc -l /tmp/$0.$1.signal|cut -d' ' -f1) -gt 200 ];then
	 tail -n 100 /tmp/$0.$1.signal > /tmp/$0.$1.signal.tmp
	 rm /tmp/$0.$1.signal
	 mv /tmp/$0.$1.signal.tmp /tmp/$0.$1.signal
	fi
	
	#for LN in `wpa_cli -i $1 "scan_result"|sed '/bssid \/ frequency \/ signal level \/ flags \/ ssid/d;/^$/d;/^\\x00/d'|cut -f3,5|sort -un`;do
	# printf $LN"\n" >> /tmp/$0.$1.signal
	#done
	wpa_cli -i $1 "scan_result"|sed '/bssid \/ frequency \/ signal level \/ flags \/ ssid/d;/^$/d;/^\\x00/d'|cut -f3,5|sort -un|sed '/^$/d' >> /tmp/$0.$1.signal
	sed -i '/^$/d' wpa_supplicant.conf
	[ -f /tmp/$0.$1.signal ] && cut -f2 /tmp/$0.$1.signal|sort -u > /tmp/$0.$1.scan
       fi
       RTO=0
       NONET=0
       FAIL=0
       DEL=9
       while [ $DEL -gt 0 ];do
        echo -en $DEL"\x8"
        sleep 1
        DEL=$(($DEL-1))
       done
      done
      ROK=0
      RTO=$(($RTO+1))
      FAIL=$(($FAIL+1))
      echo -n "|GDNS RTO($RTO)!"
      sleep 1
      if [ $RTO -ge 15 ];then
       NONET=$(($NONET+1))
       echo -n "|kill dhclient($NONET):"
       HIT=15
       while (pgrep -f dhclient.*$1 > /dev/null) && [ $HIT -gt 0 ];do
        dhclient -x $1
        pkill -f "dhclient .* $1"
        HIT=$(($HIT-1))
        echo -n $HIT"."
        sleep 1
       done
       RTO=0
       if [ $NONET -ge 6 ];then
        NID=$(wpa_cli -i $1 status|grep '^id='|sed 's/id=//')
        if [ "$NID" != "" ];then
         echo "|GRTO $NONET, disable network:"
         wpa_cli -i $1 status|grep "ssid\|^id=\|wpa_state"
         echo -e "disable_network $NID \n quit" | wpa_cli -i $1
        else
         echo "|GRTO $NONET, status:"
         wpa_cli -i $1 status|grep "ssid\|^id=\|wpa_state"
        fi
       fi
      fi
     else
      NOGW=$(($NOGW+1))
      FAIL=$(($FAIL+1))
      echo -n "|NOGW[$NOGW]."
      sleep 1
      if [ $NOGW -gt 20 ];then
       echo -n "|Fail wait NOGW[$NOGW], kill dhclient"
       HIT=15
       while (pgrep -f dhclient.*$1 > /dev/null) && [ $HIT -gt 0 ];do
        dhclient -x $1
        pkill -f "dhclient .* $1"
        HIT=$(($HIT-1))
        echo -n $HIT"."
        sleep 1
       done
       NOGW=0
      fi
     fi
    fi
   else
    echo -n "|Run dhclient"
    dhclient -nw $1 -e IF_METRIC=$((2 + $(echo $1|sed 's/wlan//') ))00
   fi
  else
   if (pgrep -f dhclient.*$1 > /dev/null);then
    echo -n "|kill dhclient:"
    HIT=15
    while [ $(pgrep -f dhclient.*$1 > /dev/null) ] && [ $HIT -gt 0 ];do
     dhclient -x $1
     pkill -f "dhclient .* $1"
     HIT=$(($HIT-1))
     echo -n $HIT"."
     sleep 1
    done
   fi
   echo -n "|wpa scan"
   wpa_cli -i $1 "scan"
   sleep 2
   wpa_cli -i $1 "scan_result"|sed '/bssid \/ frequency \/ signal level \/ flags \/ ssid/d;/^$/d;/^\\x00/d'|cut -f3,5|sort -un > /tmp/$0.$1.signal
   [ -f /tmp/$0.$1.signal ] && cut -f2 /tmp/$0.$1.signal|sort -u > /tmp/$0.$1.scan
   #wpa_cli -i $1 "scan_result"|cut -f5|sort -u|sed '/^$/d;/^\\x00/d;/bssid \/ frequency \/ signal level/d' > /tmp/$0.$1.scan
   IFS=$'\n'
   for LINE in `grep -F -f /tmp/$0.$1.scan password.tab|grep -v -f ssid.key.disable`;do
    SSID=$(echo $LINE|cut -f1)
    KEY=$(echo $LINE|cut -f2)
    SSIDS=$(grep -F "$SSID" /tmp/$0.$1.scan)
    if [ "$SSIDS" == "" ] || (echo $(grep -o "ssid=.*\|psk=.*" /tmp/wpa_supplicant.conf)|grep -qs "$SSID.*$KEY");then
     echo "$(date):SKIP $LINE"
    else
     echo "$(date):Line:"$LINE" SSIDSource:'"$SSIDS"' SSID:'"$SSID"' KEY:'"$KEY"'"
     if [ "$KEY" == "" ];then
      echo -e "\nnetwork={\n\tscan_ssid=1\n\tssid=\"$SSID\"\n}" >> /tmp/wpa_supplicant.conf
     else
      echo -e "\nnetwork={\n\tscan_ssid=1\n\tssid=\"$SSID\"\n\tpsk=\"$KEY\"\n}" >> /tmp/wpa_supplicant.conf
     fi
    fi
   done
   HIT=30
   echo -n "|Wait wpa stat:"
   while (pgrep -f wpa_supplicant.*$1 > /dev/null) && [[ ! "$(wpa_cli -i $1 status|grep 'wpa_state')" =~ "COMPLETED" ]] && [ $HIT -gt 0 ];do
    echo -n $HIT"."
    HIT=$(($HIT-1))
    sleep 1
   done
   FAIL=$(($FAIL+1))
  fi
 else
  echo -n "|wpa sup not found"
  RUNWPA=0
  while [ "$(pgrep -f wpa_supplicant.*$1)" == "" ] && (/usr/sbin/iw dev | /usr/bin/grep -qs $1);do
   RUNWPA=$(($RUNWPA+1))
   echo -n "|try run auto wpa on $1 $RUNWPA times:"
   #wpa_sup param -s:log to syslog -B background
   /sbin/wpa_supplicant -B -P /tmp/wpa_supplicant.$1.pid -i $1 -D wext -c /tmp/wpa_supplicant.conf -C /run/wpa_supplicant
   HIT=15
   while [ "$(pgrep -f wpa_supplicant.*$1)" == "" ] && [ $HIT -gt 0 ] && (/usr/sbin/iw dev | /usr/bin/grep -qs $1);do
    HIT=$(($HIT-1))
    echo -n $HIT"."
    sleep 1
   done
   if [ "$(pgrep -f wpa_supplicant.*$1)" == "" ];then
    echo -n "|wpa sup not run|"
    if [ $RUNWPA -gt 30 ];then
     echo -n "WARNING!! wpa_supplicant still not run until $RUNWPA times trial, EXIT NOW!"
     exit 2
    else
     echo -n "retry in $RUNWPA time(s)"
    fi
   fi
  done
  echo -n "|wpa.sup Run"
 fi

 if [ $FAIL -gt 0 ];then echo -n "|FAIL in $FAIL times";fi
 if [ $FAIL -gt 30 ];then
  espeak --stdout "Warning! Trouble on $(echo $1|sed 's/wlan/wireless number /'), please check"|aplay -q
  echo -n "|FAIL exceeded $FAIL times, restart all for $1, kill all related to $1:"
  echo -n "|dhclient:"
  HIT=15
  while (pgrep -f dhclient.*$1 > /dev/null) && [ $HIT -gt 0 ];do
   dhclient -x $1
   pkill -f "dhclient .* $1"
   HIT=$(($HIT-1))
   echo -n $HIT"."
   sleep 1
  done
  echo -n "|wpasup:"
  HIT=15
  while (pgrep -f wpa_supplicant.*$1 > /dev/null) && [ $HIT -gt 0 ];do
   pkill -f "wpa_supplicant .* $1"
   HIT=$(($HIT-1))
   echo -n $HIT"."
   sleep 1
  done
  truncate -s 0 /tmp/nodup.sh.wlan?.$1.old
  #/tmp/nodup.sh.wlan0.wlan1.old  /tmp/nodup.sh.wlan0.wlan2.old  /tmp/nodup.sh.wlan2.wlan1.old
  FAIL=0
  echo "|Done.."
 fi

 if [ "$(md5sum /tmp/wpa_supplicant.conf|cut -d' ' -f1)" != "$(cat /tmp/wpa_supplicant.$1.md5)" ];then
  espeak --stdout "Warning!! Wifi config has changed!"|aplay -q
  echo -n "|wpa.conf CHANGED! RESTART"
  echo -n "|dhclient:"
    HIT=15
    while (pgrep -f dhclient.*$1 > /dev/null) && [ $HIT -gt 0 ];do
     dhclient -x $1
     pkill -f "dhclient .* $1"
     HIT=$(($HIT-1))
     echo -n $HIT"."
     sleep 1
    done
    echo -n "|wpasup:"
    HIT=15
    while (pgrep -f wpa_supplicant.*$1 > /dev/null) && [ $HIT -gt 0 ];do
     pkill -f "wpa_supplicant .* $1"
     HIT=$(($HIT-1))
     echo -n $HIT"."
     sleep 1
    done
    truncate -s 0 /tmp/nodup.sh.wlan?.$1.old
    md5sum /tmp/wpa_supplicant.conf|cut -d' ' -f1 > /tmp/wpa_supplicant.$1.md5
    echo "|Done.."
 fi

done

echo "|DEV $1 not found, Exiting script.."
