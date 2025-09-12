#!/usr/bin/env bash
set -euo pipefail

CLUSTER="iot-p3"
APP_FILE="${1:-/project/p3/argocd.yaml}"  # adjust default path if needed

log(){ printf "\n[ARGO-APPLY] %s\n" "$*"; }

# If docker not accessible, use sudo for k3d
if docker info >/dev/null 2>&1; then
  SUDO_DOCKER=""
else
  SUDO_DOCKER="sudo "
  ${SUDO_DOCKER}docker ps >/dev/null 2>&1 || { echo "FATAL: sudo docker not working"; exit 1; }
fi
k3d_cmd(){ ${SUDO_DOCKER}k3d "$@"; }

# Ensure kubeconfig/context exists; if not, write it now
if ! kubectl config get-contexts -o name | grep -q "^k3d-${CLUSTER}$"; then
  log "Context k3d-${CLUSTER} not found. Writing kubeconfig..."
  mkdir -p "$HOME/.kube"
  k3d_cmd kubeconfig get "${CLUSTER}" > "$HOME/.kube/config"
  chown "$USER":"$USER" "$HOME/.kube/config" || true
fi
kubectl config use-context "k3d-${CLUSTER}" || {
  log "Could not switch to k3d-${CLUSTER}. Contexts are:"
  kubectl config get-contexts
  exit 1
}

# Ensure argocd ns + install if missing
kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl get deploy -n argocd argocd-server >/dev/null 2>&1; then
  log "Argo CD not found. Installing..."
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
fi

# Wait for CRDs before applying Application
wait_crd() {
  local crd="$1"
  until kubectl get crd "$crd" >/dev/null 2>&1; do sleep 2; done
  kubectl wait --for=condition=Established --timeout=180s "crd/${crd}" || true
}
log "Waiting for Argo CD CRDs..."
wait_crd applications.argoproj.io
wait_crd applicationsets.argoproj.io
wait_crd appprojects.argoproj.io || true
wait_crd apprprojects.argoproj.io || true

# Apply the Application
log "Applying Application: $APP_FILE"
kubectl apply -f "$APP_FILE"
kubectl get applications -n argocd

# Best-effort rollout wait for your app in 'dev'
log "Waiting (best-effort) for rollout in 'dev'..."
kubectl -n dev rollout status deploy/playground --timeout=180s || true

log "Done. Try:  curl http://localhost:8888/"
