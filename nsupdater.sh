#!/bin/bash
rarpa() {
  local idx s=${1//:}
  for (( idx=${#s} - 1; idx>=0; idx-- )); do
    printf '%s.' "${s:$idx:1}"
  done
  printf 'ip6.arpa\n'
}

shopt -s expand_aliases
curdev="$(ip route get 8.8.8.8 | sed -nr 's/.*dev ([^\ ]+).*/\1/p')"
alias ip6a='/sbin/ip -6 -o addr show dev $curdev| awk "{split(\$4,a,\"/\");print a[1]}" |grep 2001'
ip6=$(ip6a)
ip6split=($(echo "$ip6" | tr ':' '\n'))
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

ip6rev=$(echo "${ip6split[4]}${ip6split[5]}${ip6split[6]}${ip6split[7]}" | rev | sed -r 's/(.{1})/\1./g')
ip6rev="${ip6rev::-1}"
zonerev="$(echo "${ip6split[0]}${ip6split[1]}${ip6split[2]}${ip6split[3]}" | rev | sed -r 's/(.{1})/\1./g')ip6.arpa"
nsip="$(echo "${ip6split[0]}:${ip6split[1]}:${ip6split[2]}:${ip6split[3]}")::a"
nshost=$(dig -x $nsip PTR +short)
nshost=${nshost::-1}

set -euo pipefail
domain=$(cut -d ":" -f2 <<< "$(resolvectl domain $curdev)")
domainp=${domain:1}

if [ "$#" -ne 1 ] ; then
        echo "$0: exactly 1 argument expected"
        exit 3
fi
mode=$1

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
else
        echo "no option supplied"
fi;
