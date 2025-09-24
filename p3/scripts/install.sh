#!/usr/bin/env bash
set -euo pipefail

# install.sh (idempotent)
# Installs: curl, ca-certs, gnupg, lsb-release, git, docker, kubectl, k3d
# Safe to re-run on Debian/Ubuntu.

echo "== [1/5] Base tools =="
sudo apt-get update -y
sudo apt-get install -y curl ca-certificates gnupg lsb-release git jq

echo "== [2/5] Docker repo + install =="
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo $ID)/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo $ID) $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "${SUDO_USER:-$USER}" || true

if docker info >/dev/null 2>&1; then
  echo "Docker: current shell has access."
  SUDO_DOCKER=""
else
  echo "Docker: using sudo for docker/k3d."
  SUDO_DOCKER="sudo "
  ${SUDO_DOCKER}docker ps >/dev/null 2>&1 || { echo "FATAL: 'sudo docker' not working"; exit 1; }
fi

echo "== [3/5] kubectl =="
if ! command -v kubectl >/dev/null 2>&1; then
  K_VER="$(curl -s https://dl.k8s.io/release/stable.txt)"
  curl -LO "https://dl.k8s.io/release/${K_VER}/bin/linux/amd64/kubectl"
  sudo install -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
fi
kubectl version --client --output=yaml || true

echo "== [4/5] k3d =="
if ! command -v k3d >/dev/null 2>&1; then
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | sudo bash
fi
k3d version || true

echo "== [5/5] Done =="
