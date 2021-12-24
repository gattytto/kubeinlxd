#!/bin/bash
apt install -y \
      curl               \
      libarchive-tools   \
      pkg-config         \
      libsystemd-dev     \
      libdbus-glib-1-dev \
      build-essential    \
      libelf-dev \
      libseccomp-dev
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
wget -qO- https://github.com/containers/youki/zipball/main | bsdtar -xvf- -C ./ && mv containers-youki* youki
cd youki && bash ./build.sh && cd ..
cp youki/youki /usr/bin/ && chmod +x /usr/bin/youki

cat <<'EOF' >> /etc/crio/crio.conf
[crio.runtime.runtimes.youki]
runtime_path = "/usr/bin/youki"
runtime_type = "oci"
runtime_root = "/run/youki"
EOF

systemctl reload crio
export KUBECONFIG=/etc/kubernetes/admin.conf
cat <<EOF | kubectl apply -f -
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: youki
handler: youki
EOF
