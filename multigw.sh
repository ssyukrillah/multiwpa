#!/bin/bash
cd $(dirname $0)

if (ip route|grep -qs "default.*dev eth0");then
 ip route del default dev eth0
fi

if (ip route|grep -qs "192.168.99.0/24 via 192.168.93.1");then false;else ip route add 192.168.99.0/24 via 192.168.93.1;fi

if [ $(ip route|grep "^default"|wc -l) -gt 1 ];then
 TXT=""
 for NL in `ifconfig|grep -o 'inet.*netmask'|grep -v '127.0.0'|cut -d' ' -f2|cut -d'.' -f1-3`;do
  if [ "$TXT" != "" ];then TXT=$TXT"\|"$NL;else TXT=$NL;fi
 done
 if [ "$TXT" != "" ];then
  CMD=$(ip route|grep "[nexthop\|default] via [$TXT]"|grep -o 'via.*'|sed ':a;s/  / /;t a'|cut -d' ' -f1-4|sort -u|sed "s/via/nexthop via/;s/$/ weight 1/")
  if [ "$CMD" != "" ];then
   while (ip route|grep -qs 'default');do
    ip route del default
   done
   ip route add default $CMD
  fi
 fi
fi

exit

if [ "$(ip route|grep "default via .* dev wlan.* metric"|cut -d' ' -f2-5)" != "$(ip route|grep "nexthop via .* dev wlan.* weight"|sed 's/	//;:a;s/  / /;t a'|cut -d' ' -f2-5)" ];then
 if (ip route|grep -qs "nexthop");then
  $(echo "ip route del default "$(ip route|grep -o 'nexthop via .* dev wlan.* weight 1'))
 fi
 if [ "$(ip route|grep 'default'|grep -v 'metric')" != "" ];then
  $(echo 'ip route del '$(ip route|grep 'default'|grep -v 'metric'))
 fi
 if [ $(ip route|grep '^default via .* dev wlan.*'|wc -l) -gt 1 ];then
  $(echo "ip route add default "$(ip route|grep "default via .* dev wlan.* metric"|cut -d' ' -f2-5|sed 's/^/nexthop /;s/$/ weight 1/'))
 fi
fi
