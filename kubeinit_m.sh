#!/bin/bash
shopt -s expand_aliases

kubeadm init  \
--config kubeadm.yaml --ignore-preflight-errors=all --v=7 --upload-certs
