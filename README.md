refer to [this](https://www.eclipse.org/che/docs/che-7/installation-guide/installing-che-on-minikube/) for context

node commands:

shared root :shrugs:
```bash
mount --make-rshared /
```
set pure-ipv6 options to kubelet from snap:
````bash
snap set kubelet \
config=/var/lib/kubelet/config.yaml \
container-runtime=remote \
container-runtime-endpoint=unix:///run/crio/crio.sock \
feature-gates=IPv6DualStack=true \
kubeconfig=/etc/kubernetes/kubelet.conf \
network-plugin=cni \
node-ip=$(ip -6 -o addr show dev eth0| awk "{split(\$4,a,\"/\");print a[1]}" |grep 2001)
```` 

kill the cluster:
```bash
kubeadm reset -f && rm -rf /etc/kubernetes/ && systemctl daemon-reload && systemctl stop snap.kubelet.daemon && crictl stopp $(crictl pods -q --no-trunc) && crictl rmp -a && rm -f ~/.kube/config && ip link delete cni0 && snap restart kubelet.daemon
```

