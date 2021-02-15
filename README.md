node commands:

shared root :shrugs:
```bash
mount --make-rshared /
```

kill the cluster:
```bash
kubeadm reset -f && rm -rf /etc/kubernetes/ && systemctl daemon-reload && systemctl stop snap.kubelet.daemon && crictl stopp $(crictl pods -q --no-trunc) && crictl rmp -a && rm -f ~/.kube/config && ip link delete cni0 && snap restart kubelet.daemon
```

