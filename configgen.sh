#!/bin/bash
shopt -s expand_aliases
alias ip4a='/sbin/ip -4 -o addr show dev eth0| awk "{split(\$4,a,\"/\");print a[1]}"'
alias ip6a='/sbin/ip -6 -o addr show dev eth0| awk "{split(\$4,a,\"/\");print a[1]}" |grep 2001'                                                                                                                                                    

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

kubeadm config print init-defaults --component-configs=KubeletConfiguration > "$KUBEADM_CONFIG"

yq eval 'select(di == 0) .nodeRegistration.criSocket = "unix:///var/run/crio/crio.sock"' -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.name = \"$(hostname)\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .localAPIEndpoint.advertiseAddress= \"$(ip6a)\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.node-ip = \"$(ip6a)\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.cluster-dns = \"1100:200:96::a\"" -i "$KUBEADM_CONFIG"
yq eval 'select(di == 0) .nodeRegistration.kubeletExtraArgs.container-runtime = "remote"' -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.container-runtime-endpoint = \"unix:///run/crio/crio.sock\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.cgroup-driver=\"cgroupfs\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.environmentFile=\"/var/lib/kubelet/kubeadm-flags.env\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.network-plugin=\"cni\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.authorization-mode=\"AlwaysAllow\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.kubeconfig=\"/etc/kubernetes/kubelet.conf\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.config=\"/var/lib/kubelet/config.yaml\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 0) .nodeRegistration.kubeletExtraArgs.feature-gates=\"IPv6DualStack=true\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .controlPlaneEndpoint = \"[$(ip6a)]:6443\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .networking.serviceSubnet = \"1100:200:96::/112\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .scheduler.extraArgs.address = \"1100:200::1\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .scheduler.extraArgs.bind-address = \"$(ip6a)\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .controllerManager.extraArgs.bind-address = \"$(ip6a)\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .controllerManager.extraArgs.enable-hostpath-provisioner = \"true\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .controllerManager.extraArgs.cluster-cidr = \"1100:200:244::/104\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .controllerManager.extraArgs.node-cidr-mask-size = \"120\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .controllerManager.extraArgs.service-cluster-ip-range = \"1100:200:96::/112\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .apiServer.certSANs = [ \"localhost\", \"::1\", \"$(ip6a)\", \"1100:200::1\", \"1100:200:96::1\", \"1100:200:96::a\"]" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .apiServer.extraArgs.advertise-address = \"$(ip6a)\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .apiServer.extraArgs.anonymous-auth = \"true\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .apiServer.extraArgs.etcd-servers = \"https://[$(ip6a)]:2379\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .apiServer.extraArgs.service-cluster-ip-range = \"1100:200:96::/112\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .etcd.local.dataDir = \"/var/lib/etcd\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .etcd.local.extraArgs.advertise-client-urls = \"https://[$(ip6a)]:2379\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .etcd.local.extraArgs.initial-advertise-peer-urls = \"https://[$(ip6a)]:2380\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .etcd.local.extraArgs.initial-cluster = \"$(hostname)=https://[$(ip6a)]:2380\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .etcd.local.extraArgs.listen-client-urls = \"https://[$(ip6a)]:2379\"" -i "$KUBEADM_CONFIG"
yq eval "select (di == 1) .etcd.local.extraArgs.listen-peer-urls = \"https://[$(ip6a)]:2380\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 2) .authentication.anonymous.enabled = true" -i "$KUBEADM_CONFIG"
yq eval "select(di == 2) .authentication.webhook.enabled = false" -i "$KUBEADM_CONFIG"
yq eval "select(di == 2) .authorization.mode = \"AlwaysAllow\"" -i "$KUBEADM_CONFIG"
yq eval "select(di == 2) .clusterDNS = [ \"1100:200:96::a\"]" -i "$KUBEADM_CONFIG"
yq eval "select(di == 2) .healthzBindAddress = \"::1\"" -i "$KUBEADM_CONFIG"
