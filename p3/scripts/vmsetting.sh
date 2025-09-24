#!/usr/bin/env bash
set -euo pipefail

# Optional helper to create a VirtualBox VM without Vagrant.
# Use only if you want to auto-create the VM; otherwise create one manually.

VM="${VM_NAME:-p3}"
RAM_MB="${RAM_MB:-4096}"
CPUS="${CPUS:-2}"
DISK_GB="${DISK_GB:-20}"
SSH_PORT="${SSH_PORT:-2222}"
ARGO_PORT="${ARGO_PORT:-8080}"
APP_PORT="${APP_PORT:-8888}"
K8S_API_PORT="${K8S_API_PORT:-6443}"
ISO="${ISO_PATH:-$HOME/goinfre/debian-13.1.0-amd64-netinst.iso}"

echo "[INFO] Creating/modifying VM '${VM}' (VirtualBox CLI) ..."
VBoxManage createvm --name "$VM" --register || true
VBoxManage modifyvm "$VM" --memory "$RAM_MB" --cpus "$CPUS" --ostype "Debian_64" --nic1 nat
for rule in ssh argo app k8sapi; do VBoxManage modifyvm "$VM" --natpf1 delete "$rule" 2>/dev/null || true; done
VBoxManage modifyvm "$VM" --natpf1 "ssh,tcp,127.0.0.1,${SSH_PORT},,22"
VBoxManage modifyvm "$VM" --natpf1 "argo,tcp,127.0.0.1,${ARGO_PORT},,8080"
VBoxManage modifyvm "$VM" --natpf1 "app,tcp,127.0.0.1,${APP_PORT},,8888"
VBoxManage modifyvm "$VM" --natpf1 "k8sapi,tcp,127.0.0.1,${K8S_API_PORT},,6443"

echo "[INFO] VM created. Install Debian/Ubuntu manually, then run scripts/setup.sh inside the VM."
