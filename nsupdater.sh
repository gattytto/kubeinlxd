#!/bin/bash
if [ "$#" -ne 1 ] ; then
        echo "$0: exactly 1 argument expected"
        exit 3
fi
mode=$1
timestamp=$(date +%s)
rarpa() {
  local idx s=${1//:}
  for (( idx=${#s} - 1; idx>=0; idx-- )); do
    printf '%s.' "${s:$idx:1}"
  done
  printf 'ip6.arpa\n'
}

shopt -s expand_aliases
curdev="$(ip route get 8.8.8.8 | sed -nr 's/.*dev ([^\ ]+).*/\1/p')"

set -euo pipefail

alias ip6a='/sbin/ip -6 -o addr show dev $curdev| awk "{split(\$4,a,\"/\");print a[1]}" |grep 2001'
ip6=$(ip6a)
ip6split=($(echo "$ip6" | tr ':' '\n'))
if [ "${#ip6split[@]}" -ne 8 ]; then
        IFS='::' read -a split2 <<< $ip6
        end=$(echo "${split2[$((${#split2}+1))]}")
        ip6=$(echo "${split2[0]}:${split2[1]}:${split2[2]}:${split2[3]}:0:0:0:${end}")
fi

ip6split=($(echo "$ip6" | tr ':' '\n'))

if [ "${#ip6split[@]}" -eq 8 ]; then
        for i in {0..7}
        do
                if [ "${#ip6split[$i]}" -ne 4 ] ; then
                        num=${#ip6split[$i]}
                        num=$((4-$num))
                        for r in $(seq 0 $(($num-1)))
                        do
                                ip6split[$i]="0${ip6split[$i]}"
                        done
                fi
        done
fi

ip6rev=$(echo "${ip6split[4]}${ip6split[5]}${ip6split[6]}${ip6split[7]}" | rev | sed -r 's/(.{1})/\1./g')
ip6rev="${ip6rev::-1}"
zonerev="$(echo "${ip6split[0]}${ip6split[1]}${ip6split[2]}${ip6split[3]}" | rev | sed -r 's/(.{1})/\1./g')ip6.arpa"

nshost=""
domain=$(cut -d ":" -f2 <<< "$(resolvectl domain $curdev)")
domainp=${domain:1}
nsip="$(echo "${ip6split[0]}:${ip6split[1]}:${ip6split[2]}:${ip6split[3]}")::a"

if [ $mode != "bind" ]; then
        nshost=$(dig -x $nsip PTR +short)
        nshost=${nshost::-1}
else
        nshost=$(echo "$(hostname).$domainp")
fi

domainsplit=($(echo "$domainp" | tr '.' '\n'))
domain1p="${domainsplit[0]}"


if [ $mode = "up" ]; then
        echo "server $nshost
        zone $domainp.
        update add $(hostname).$domainp. 30 AAAA $(ip6a)
        send
        zone $zonerev.
        server $nshost
        update add $ip6rev.$zonerev 30 PTR $(hostname).$domainp.
        send" |nsupdate -6 -v
elif [ $mode = "down" ]; then
        echo "server $nshost
        zone $domainp.
        update delete $(hostname).$domainp. 30 AAAA $(ip6a)
        send
        zone $zonerev.
        server $nshost
        update delete $ip6rev.$zonerev 30 PTR $(hostname).$domainp.
        send
        " |nsupdate -6 -v
elif [ $mode = "bind" ]; then
        echo "acl @$domain1p {
    $(echo "${ip6split[0]}:${ip6split[1]}:${ip6split[2]}:${ip6split[3]}")::/64;
};

options {
   directory \"/var/cache/bind\";
   preferred-glue AAAA;
   allow-query { @$domain1p; };
   allow-transfer { none; };
   recursion no;
   forwarders {
       1.1.1.1;
   };
   listen-on-v6 { $nsip; };
   dnssec-validation no;
   auth-nxdomain no;
};" > /etc/bind/named.conf.options
        echo "zone \"$domainp\" {
   type master;
   file \"/var/lib/bind/db.$domainp\";
   allow-update { @$domain1p; };
   allow-transfer { @$domain1p; };
   forwarders {};
};

zone \"$zonerev\" {
        type master;
        file \"/var/lib/bind/db.$zonerev\";
        allow-update { @$domain1p; };
        allow-transfer {@$domain1p; };
        forwarders {};
};" > /etc/bind/named.conf.local

        echo "\$ORIGIN .
\$TTL 86400      ; 1 day
$zonerev IN SOA $(hostname).$domainp. root.$domainp. (
                                $timestamp        ; serial
                                28800      ; refresh (8 hours)
                                7200       ; retry (2 hours)
                                2419200    ; expire (4 weeks)
                                86400      ; minimum (1 day)
                                )
                        NS      $(hostname).$domainp.
\$ORIGIN $zonerev.
\$TTL 3600       ; 1 hour
a.0.0.0.0.0.0.0.0.0.0.0.0.0.0 PTR $(hostname).$domainp." > $(echo "/var/lib/bind/db.$zonerev")

        echo "\$ORIGIN .
\$TTL 3600       ; 1 hour
$domainp IN SOA $(hostname).$domainp. root.$domainp. (
                                $timestamp        ; serial
                                28800      ; refresh (8 hours)
                                7200       ; retry (2 hours)
                                2419200    ; expire (4 weeks)
                                86400      ; minimum (1 day)
                                )
                                NS      $(hostname).$domainp.
                        AAAA    $nsip
\$ORIGIN $domainp.
$(hostname)                     AAAA    $nsip" > $(echo "/var/lib/bind/db.$domainp")

        echo "interface vmbr0 {
        AdvSendAdvert on;
        AdvLinkMTU 1480;
        MinRtrAdvInterval 60;
        MaxRtrAdvInterval 180;
        prefix $ip6/64 {
            AdvRouterAddr on;
            AdvPreferredLifetime 600;
            AdvValidLifetime 3600;
        };
        route ::/0 {
        };
        RDNSS $nsip {};
        DNSSL $domainp {};
};" > /etc/radvd.conf

else
        echo "no option supplied"
fi;
