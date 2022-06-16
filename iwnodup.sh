#!/bin/bash

#iwconfig wlan0|grep -o 'ESSID:.*\|Signal level=.*'|sed ':a;s/^ //;t a;:b;s/ $//;t b;;s/ESSID:"//;s/"$//;s/Signal level=-//;s/dBm//'
if [ ! -f /tmp/$0.cnt ];then echo 0 > /tmp/$0.cnt;fi

OLDCNT=$(cat /tmp/$0.cnt)

function mydelay {
 if [ "$1" == "" ] || [ $1 -lt 1 ];then exit;fi
 CNT=$1
 while [ $CNT -gt 0 ];do
  echo -n "$CNT"
  CNT=$(($CNT-1))
  sleep 1
 done
 echo -n "|"
}

function getiw {
 IFS=$'\n'
 CNT=0
 for LN in `iwconfig $1|grep -o 'ESSID:.*\|Signal level=.*'|sed ':a;s/^ //;t a;:b;s/ $//;t b;;s/ESSID:"//;s/"$//;s/Signal level=-//;s/ dBm//;s/dBm//'`;do
  if [ $CNT -gt 0 ];then
   echo -n "	"
  fi
  CNT=$(($CNT+1))
  echo -n $LN
 done
}

DEV=$(iw dev|grep -o "Interface.*"|sed 's/Interface //')

IFS=$'\n'
for DA in $DEV;do
 for DB in $DEV;do
  if [ "$DA" != "$DB" ];then
   echo -n "$DA:$DB|"
   SA=$(getiw $DA)
   SB=$(getiw $DB)
   echo -n "$DA:$(echo $SA|sed 's/	/->/')|$DB:$(echo $SB|sed 's/	/->/')|"
   while [ "$(echo $SA|cut -f1)" == "$(echo $SB|cut -f1)" ];do
    echo $(($(cat /tmp/$0.cnt)+1)) > /tmp/$0.cnt
    if [ $(echo $SA|cut -f2) -lt $(echo $SB|cut -f2) ];then
     #DA
     NID=$(wpa_cli -i $DA status|grep "^id="|cut -d'=' -f2)
     echo -n "ID:$NID|"
     echo -e "disable_network $NID \n quit" | wpa_cli -i $DA > /dev/null
     echo "$DA	$NID" >> /tmp/$0.disable
    elif [ $(echo $SA|cut -f2) -gt $(echo $SB|cut -f2) ];then
     #DB
     NID=$(wpa_cli -i $DB status|grep "^id="|cut -d'=' -f2)
     echo -n "ID:$NID|"
     echo -e "disable_network $NID \n quit" | wpa_cli -i $DB > /dev/null
     echo "$DB	$NID" >> /tmp/$0.disable
    fi
    mydelay 5
    SA=$(getiw $DA)
    SB=$(getiw $DB)
    echo -n "$DA:$(echo $SA|sed 's/	/->/')|$DB:$(echo $SB|sed 's/	/->/')|"
   done
   echo "END"
  fi
 done
done

if [ $OLDCNT -eq $(cat /tmp/$0.cnt) ] && [ $OLDCNT -gt 0 ];then
 echo $(($OLDCNT-1)) > /tmp/$0.cnt
 echo "Counter $(cat /tmp/$0.cnt)"
fi

if [ -f /tmp/$0.cnt ] && [ -f /tmp/$0.disable ] && [ $(cat /tmp/$0.cnt) -le 0 ] && [ $(wc -l /tmp/$0.disable|cut -d' ' -f1) -gt 0 ];then
 echo "Re-Enable:"
 IFS=$'\n'
 for LN in $(cat /tmp/$0.disable);do
  echo "Re-Enable:$LN"
  echo -e "enable_network $(echo $LN|cut -f2) \n quit" | wpa_cli -i $(echo $LN|cut -f1) > /dev/null
  sleep 1
 done
 rm -f /tmp/$0.disable
fi
