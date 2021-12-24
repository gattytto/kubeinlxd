#!/bin/bash
if test -f /etc/kubernetes/admin.conf; then
  export KUBECONFIG=/etc/kubernetes/admin.conf
  cat <<EOF | kubectl apply -f -
  apiVersion: node.k8s.io/v1
  kind: RuntimeClass
  metadata:
    name: youki
  handler: youki
EOF
exit
fi

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
source $HOME/.cargo/env
cd /root/kubeinlxd
#wget -qO- https://github.com/containers/youki/zipball/main | bsdtar -xvf- -C ./ && mv containers-youki* youki
git clone https://github.com/containers/youki
cd youki && bash ./build.sh && cd ..
cp youki/youki /usr/bin/ && chmod +x /usr/bin/youki
rm -rf youki

if ! grep -q youki /etc/crio/crio.conf; then
  cat <<'EOF' >> /etc/crio/crio.conf
[crio.runtime.runtimes.youki]
runtime_path = "/usr/bin/youki"
runtime_type = "oci"
runtime_root = "/run/youki"
EOF
fi

systemctl reload crio

apt remove -y \
      curl               \
      libarchive-tools   \
      pkg-config         \
      libsystemd-dev     \
      libdbus-glib-1-dev \
      build-essential    \
      libelf-dev \
      libseccomp-dev
apt clean
