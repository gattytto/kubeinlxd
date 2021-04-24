kubeadm join \
        [master]:6443 \
        --token token \
        --discovery-token-ca-cert-hash sha256:something \
        --ignore-preflight-errors=all --v=7
