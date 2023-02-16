#!/bin/bash
shopt -s expand_aliases
curdev="$(ip route get 8.8.8.8 | sed -nr 's/.*dev ([^\ ]+).*/\1/p')"
kubeversion=$(kubeadm version -o short | awk '{ print substr($1,2)}')
alias ip4a='/sbin/ip -4 -o addr show dev $curdev| awk "{split(\$4,a,\"/\");print a[1]}"'
alias ip6a='/sbin/ip -6 -o addr show dev $curdev| awk "{split(\$4,a,\"/\");print a[1]}" |grep 2001'

alias POD_CIDR='echo "1100:200::"'
alias POD_SVC_CIDR='echo "1101:300:1:2::"'
set -euo pipefail

KUBEADM_CONFIG="${1-kubeadm.yaml}"
echo "Printing to $KUBEADM_CONFIG"

if [ -d "$KUBEADM_CONFIG" ]; then
    echo "$KUBEADM_CONFIG is a directory!"
    exit 1
fi

if [ ! -d $(dirname "$KUBEADM_CONFIG") ]; then
    echo "please create directory $(dirname $KUBEADM_CONFIG)"
    exit 1
fi

if [ ! $(which yq) ]; then
    echo "please install yq"
    exit 1
fi

if [ ! $(which kubeadm) ]; then
    echo "please install kubeadm"
    exit 1
fi

kubeadm config print init-defaults --component-configs=KubeletConfiguration | tee $KUBEADM_CONFIG > /dev/null

yq eval 'select(di == 0) .nodeRegistration.criSocket = "unix:///var/run/crio/crio.sock"' -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.name = \"$(hostname)\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .localAPIEndpoint.advertiseAddress = \"$(ip6a)\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.node-ip = \"$(ip6a)\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.cluster-dns = \"$(POD_SVC_CIDR)a\"" -i "$KUBEADM_CONFIG"
yq eval 'select(di == 0) .nodeRegistration.kubeletExtraArgs.container-runtime = "remote"' -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.container-runtime-endpoint = \"unix:///run/crio/crio.sock\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.cgroup-driver=\"cgroupfs\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.environmentFile=\"/var/lib/kubelet/kubeadm-flags.env\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.network-plugin=\"cni\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.authorization-mode=\"RBAC\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.kubeconfig=\"/etc/kubernetes/kubelet.conf\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.config=\"/var/lib/kubelet/config.yaml\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .kubernetesVersion=\"$kubeversion\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .controlPlaneEndpoint = \"[$(ip6a)]:6443\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .networking.serviceSubnet = \"$(POD_SVC_CIDR)/112\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .scheduler.extraArgs.bind-address = \"$(ip6a)\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .controllerManager.extraArgs.bind-address = \"$(ip6a)\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .controllerManager.extraArgs.enable-hostpath-provisioner = \"true\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .controllerManager.extraArgs.cluster-cidr = \"$(POD_CIDR)/104\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .controllerManager.extraArgs.node-cidr-mask-size = \"120\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .controllerManager.extraArgs.service-cluster-ip-range = \"$(POD_SVC_CIDR)/112\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .apiServer.certSANs = [ \"localhost\", \"::1\", \"$(ip6a)\", \"$(POD_CIDR)1\", \"$(POD_SVC_CIDR)1\", \"$(POD_SVC_CIDR)a\"]" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .apiServer.extraArgs.advertise-address = \"$(ip6a)\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .apiServer.extraArgs.authorization-mode = \"Node,RBAC\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .apiServer.extraArgs.etcd-servers = \"https://[$(ip6a)]:2379\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .apiServer.extraArgs.service-cluster-ip-range = \"$(POD_SVC_CIDR)/112\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .etcd.local.dataDir = \"/var/lib/etcd\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .etcd.local.extraArgs.advertise-client-urls = \"https://[$(ip6a)]:2379\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .etcd.local.extraArgs.initial-advertise-peer-urls = \"https://[$(ip6a)]:2380\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .etcd.local.extraArgs.initial-cluster = \"$(hostname)=https://[$(ip6a)]:2380\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .etcd.local.extraArgs.listen-client-urls = \"https://[$(ip6a)]:2379\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .etcd.local.extraArgs.listen-peer-urls = \"https://[$(ip6a)]:2380\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 2) .authentication.webhook.enabled = true" -i "$KUBEADM_CONFIG"
yq eval "select(di == 2) .clusterDNS = [ \"$(POD_SVC_CIDR)a\"]" -i "$KUBEADM_CONFIG"
yq eval "select(di == 2) .healthzBindAddress = \"::1\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 2) .serverTLSBootstrap = true" -i "$KUBEADM_CONFIG"
yq eval "select(di == 2) .cgroupDriver = \"cgroupfs\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 2) .enforceNodeAllocatable[0] = \"pods\"" -i "$KUBEADM_CONFIG"
