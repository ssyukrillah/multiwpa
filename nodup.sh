#!/bin/bash
#./iwnodup.sh >> /var/log/mylog/iwnodup.log
#exit

IFS=$'\n'
if [ $(find /tmp -type f -iname "*wlan?.signal"|wc -l) -le 0 ];then echo "$(date):NODUP NOT RUN, signal FILE not Found";exit;fi
echo "START NODUP:$(date)"
if [ ! -f /tmp/nodup.cnt ];then echo 0 > /tmp/nodup.cnt;fi
ISDIS=false

for DEV in `iw dev|grep 'Interface'|sed 's/.*Interface //'|grep -v 'wlan.mon$'`;do
 W0=$(for LN in `wpa_cli -i $DEV status|grep '^bssid=\|^id=\|^wpa_state=\|^ssid='|sed 's/bssid=//;s/ssid=//;s/id=//;s/wpa_state=//'`;do echo -n $LN"|";done)
  if [ "$(echo $W0|cut -d'|' -f4)" == "COMPLETED" ] && (grep -qs $(echo $W0|cut -d'|' -f1) bssid.disable);then
   echo -n "|$DEV dis $W0"
   echo -e "disable_network $(echo $W0|cut -d'|' -f3) \n quit" | wpa_cli -i $DEV
  fi
done

for W0 in `./calc.sh|cut -f2`;do
 RUN=false
 if (iw dev|grep -qs $W0) && (pgrep -f "wpa_supplicant.*$W0" > /dev/null);then
  for W1 in `./calc.sh|cut -f2`;do
   if (iw dev|grep -qs $W1) && (pgrep -f "wpa_supplicant.*$W1" > /dev/null);then
    if [ "$W0" == "$W1" ] && [ $RUN == false ];then
     RUN=true
    elif [ "$W0" != "$W1" ] && [ $RUN == true ];then
     R0=$(for LN in `wpa_cli -i $W0 status|grep '^bssid=\|^id=\|^wpa_state=\|^ssid='|sed 's/bssid=//;s/ssid=//;s/id=//;s/wpa_state=//'`;do echo -n $LN"|";done)
     R1=$(for LN in `wpa_cli -i $W1 status|grep '^bssid=\|^id=\|^wpa_state=\|^ssid='|sed 's/bssid=//;s/ssid=//;s/id=//;s/wpa_state=//'`;do echo -n $LN"|";done)
     echo -n "$W0 : $W1 : R0=$R0 : R1=$R1 : " 
     if [ "$(echo $R0|cut -d'|' -f4)" == "COMPLETED" ] && [ "$(echo $R1|cut -d'|' -f4)" == "COMPLETED" ];then
      IFS=$'\n'
      DUPE=false
      for LN in `sed '/^$/d' nodup.lst`;do
       #echo $LN 
       if [ "$(echo $R0|cut -d'|' -f3)" == "$(echo $R1|cut -d'|' -f3)" ];then
        echo "Duplikasi SSID yang sama"
        DUPE=true
       elif [[ "$LN" =~ "$(echo $R0|cut -d'|' -f2)" ]] && [[ "$LN" =~ "$(echo $R1|cut -d'|' -f2)" ]];then
        echo "Duplikasi Network yang sama '$LN' pada $W0:$R0 & $W1:$R1"
        DUPE=true
       fi
      done
      if [ $DUPE == true ];then
       #if [ -f /tmp/$0.$W0.$W1.old ];then
       # echo -n "$W1 en $(cat /tmp/$0.$W0.$W1.old)|"
       # echo -e "enable_network $(cat /tmp/$0.$W0.$W1.old) \n quit" | wpa_cli -i $W1
       #fi
       if (grep -qsF "^"$(echo $R1|cut -d'|' -f3)"$" /tmp/$0.$W0.$W1.old);then
        echo -n "$W1 ALREADY DISABLED $(echo $R1|cut -d'|' -f3)|"
       else
        echo -n "$W1 dis $(echo $R1|cut -d'|' -f3)|"
        echo -e "disable_network $(echo $R1|cut -d'|' -f3) \n quit" | wpa_cli -i $W1
        echo $R1|cut -d'|' -f3 >> /tmp/$0.$W0.$W1.old
        ISDIS=true
       fi
      else
       echo "OK:No Duplicate"
      fi
     else
      echo "Not Completed"
     fi
    fi  
   fi
  done
 fi
done

if [ $ISDIS == true ];then
 echo $(($(cat /tmp/nodup.cnt)+1)) > /tmp/nodup.cnt
elif [ -f ./iwnodup.sh ];then
 echo "Run iwnodup.sh"
 ./iwnodup.sh >> /var/log/mylog/iwnodup.log
fi
echo "Counter : $(cat /tmp/nodup.cnt)"
echo "END NODUP:$(date)"
