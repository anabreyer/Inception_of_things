#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# install_k3s_server.sh
#
# Purpose:
#   - Runs inside VM "aaduan-bS".
#   - Installs K3s in *server* mode (control plane).
#   - Makes kubectl usable by the 'vagrant' user.
#   - Exposes the cluster join token via the shared /vagrant folder so the worker
#     VM can join automatically.
#
# Notes:
#   - /vagrant is a synced folder between host and guest provided by Vagrant.
#   - K3s stores its server token at /var/lib/rancher/k3s/server/node-token
#   - We set kubeconfig mode to 644 so 'vagrant' can read it without sudo.
# -----------------------------------------------------------------------------

set -euo pipefail  # Exit on error, undefined var is error, and fail in pipelines

echo "[server] Preparing dependencies..."

# Ensure 'curl' exists (Debian minimal images may not have it).
if ! command -v curl >/dev/null 2>&1; then
  # Update apt package lists
  sudo apt-get update -y
  # Install curl (used to fetch the K3s installer)
  sudo apt-get install -y curl
fi

echo "[server] Installing K3s (server mode)..."

# Install K3s in server mode.
# --write-kubeconfig-mode 644 allows non-root user (vagrant) to read kubeconfig.
# The official K3s install script figures out the right binaries/systemd units.
curl -sfL https://get.k3s.io | sh -s - server --write-kubeconfig-mode 644

# Make sure the kubeconfig file is owned by 'vagrant' for convenience.
# This lets us run `kubectl` without sudo inside the VM.
sudo chown vagrant:vagrant /etc/rancher/k3s/k3s.yaml

# Extract the cluster join token and put it in /vagrant so the worker can read it.
# /vagrant maps to the project folder on your host.
sudo cat /var/lib/rancher/k3s/server/node-token > /vagrant/node-token
echo "[server] Saved join token to /vagrant/node-token"

# Optional: quick check to show what nodes are known at this moment.
# Right after server install, usually only the server shows up (or none if not ready yet).
echo "[server] Nodes known so far (may be empty for ~30s while components start):"
kubectl get nodes -o wide || true
