#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-iot-p3}"

log(){ printf "\n[CREATE-CLUSTER] %s\n" "$*"; }

# docker/k3d via sudo fallback
if docker info >/dev/null 2>&1; then
  SUDO_DOCKER=""
else
  SUDO_DOCKER="sudo "
  ${SUDO_DOCKER}docker ps >/dev/null 2>&1 || { echo "FATAL: sudo docker not working"; exit 1; }
fi
k3d_cmd(){ ${SUDO_DOCKER}k3d "$@"; }

if ! k3d_cmd cluster list | grep -q "^${CLUSTER_NAME}\b"; then
  log "Creating k3d cluster '${CLUSTER_NAME}' (1 server, 1 agent, LB 8888->80) ..."
  k3d_cmd cluster create "${CLUSTER_NAME}" --api-port 6550 -p "8888:80@loadbalancer" --agents 1
else
  log "Cluster '${CLUSTER_NAME}' already exists. Skipping create."
fi

log "Writing kubeconfig & switching context ..."
mkdir -p "$HOME/.kube"
k3d_cmd kubeconfig get "${CLUSTER_NAME}" > "$HOME/.kube/config"
chown "$USER":"$USER" "$HOME/.kube/config" || true

kubectl config use-context "k3d-${CLUSTER_NAME}" || true

log "Waiting for nodes to be Ready ..."
kubectl wait --for=condition=Ready node --all --timeout=300s

log "Ensuring namespaces dev/argocd exist ..."
kubectl create ns dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl get nodes
kubectl get ns
echo "Cluster '${CLUSTER_NAME}' is ready. http://localhost:8888 -> Ingress 80"
