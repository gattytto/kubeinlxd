#!/bin/bash
shopt -s expand_aliases
alias ip4a='/sbin/ip -4 -o addr show dev eth0| awk "{split(\$4,a,\"/\");print a[1]}'
alias ip6a='/sbin/ip -6 -o addr show dev eth0| awk "{split(\$4,a,\"/\");print a[1]}" |grep 2001'

kubeadm init  \
--config kubeadm.yaml --ignore-preflight-errors=all --v=7 --upload-certs
