#!/bin/bash
#exit
[ $(find /tmp -type f -iname "*wlan?.signal"|wc -l) -le 0 ] && exit

[ ! -f /tmp/scan.md5 ] && echo "0" > /tmp/scan.md5

if [ "$(cat /tmp/autowpa2.sh.wlan?.scan|md5sum|cut -d' ' -f1)" != "$(cat /tmp/scan.md5)" ];then
 [ -f /tmp/uniq.all.scan ] && rm /tmp/uniq.all.scan
 for NF in /tmp/autowpa2.sh.wlan?.scan;do
  if [ ! -f /tmp/uniq.all.scan ];then
   sort -u $NF|sed 's/$/$/' > /tmp/uniq.all.scan
  else
   grep -f /tmp/uniq.all.scan $NF|sort -u|sed 's/$/$/' > /tmp/uniq.all.scan.tmp
   rm /tmp/uniq.all.scan
   mv /tmp/uniq.all.scan.tmp /tmp/uniq.all.scan
  fi
 done
 #sed -i 's/$/$/' uniq.all.scan
 cat /tmp/autowpa2.sh.wlan?.scan|md5sum|cut -d' ' -f1 > /tmp/scan.md5
fi

for NF in /tmp/*wlan?.signal;do
if (iw dev|grep -qs $(echo "$NF"|grep -o "wlan."));then
 if [ -f /tmp/uniq.all.scan ] && [ $(wc -l /tmp/uniq.all.scan|cut -d' ' -f1) -gt 0 ];then
  echo -n $(echo "("$(grep -f /tmp/uniq.all.scan $NF|cut -f1|sed 's/^-//')")/"$(grep -f /tmp/uniq.all.scan $NF|wc -l)|sed ':a;s/ /+/;t a'|bc)"	"
 else
  echo -n $(echo "("$(cut $NF -f1|sed 's/^-//')")/"$(wc -l $NF|cut -d' ' -f1)|sed ':a;s/ /+/;t a'|bc)"	"
 fi
 echo -n $(echo "$NF"|grep -o "wlan.")
 echo "	"$(iw $(echo "$NF"|grep -o "wlan.") info|grep ssid|cut -f2-|cut -d' ' -f2-)
fi
done|sort -rn
