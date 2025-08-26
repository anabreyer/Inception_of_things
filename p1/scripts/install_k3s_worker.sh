#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# install_k3s_worker.sh
#
# Purpose:
#   - Runs inside VM "aaduan-bSW".
#   - Waits for the server to drop its join token into /vagrant/node-token.
#   - Installs K3s in *agent* (worker) mode and joins the server at 192.168.56.110.
#
# Notes:
#   - The server writes /vagrant/node-token during its provisioning.
#   - K3S_URL points to the server’s API endpoint (default 6443/TCP).
#   - K3S_TOKEN must match the server’s node-token to authorize the join.
# -----------------------------------------------------------------------------

set -euo pipefail  # Exit on error, undefined var is error, and fail in pipelines

echo "[worker] Preparing dependencies..."

# Ensure 'curl' exists for fetching the K3s installer.
if ! command -v curl >/dev/null 2>&1; then
  sudo apt-get update -y
  sudo apt-get install -y curl
fi

# Wait until the server provisioning has created /vagrant/node-token.
# The server and worker provisioners can run in parallel; the worker might
# start first, so we loop until the token is present and non-empty.
until [ -s /vagrant/node-token ]; do
  echo "[worker] Waiting for /vagrant/node-token to appear..."
  sleep 2
done

# Read the token
TOKEN="$(cat /vagrant/node-token)"

echo "[worker] Installing K3s (agent mode), joining server at 192.168.56.110:6443..."

# Install K3s in agent mode, pointing to the server and using the token we just read.
# The installer sets up the k3s-agent systemd service automatically.
curl -sfL https://get.k3s.io | \
  K3S_URL="https://192.168.56.110:6443" \
  K3S_TOKEN="$TOKEN" \
  sh -s - agent

# Optional: quick check to confirm the agent service is running.
if systemctl is-active --quiet k3s-agent; then
  echo "[worker] k3s-agent is active"
else
  echo "[worker] WARNING: k3s-agent is not active yet" >&2
fi


