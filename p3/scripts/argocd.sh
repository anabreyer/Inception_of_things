#!/usr/bin/env bash
set -euo pipefail

log(){ printf "\n[ARGOCD] %s\n" "$*"; }

log "Ensuring argocd namespace exists ..."
kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f -

log "Downloading Argo CD manifest locally (cached) ..."
CACHE_DIR="${CACHE_DIR:-$HOME/.cache/argocd}"
mkdir -p "${CACHE_DIR}"
MAN="${CACHE_DIR}/install.yaml"
if [ ! -f "${MAN}" ]; then
  curl -L https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml -o "${MAN}"
fi

if ! kubectl get deploy -n argocd argocd-server >/dev/null 2>&1; then
  log "Applying Argo CD manifest with retries ..."
  for i in 1 2 3 4 5; do
    echo "[TRY $i] kubectl apply --request-timeout=5m"
    if kubectl apply -n argocd -f "${MAN}" --request-timeout=5m; then
      echo "✅ Argo CD applied."
      break
    fi
    echo "…timeout; sleep 10"; sleep 10
  done
else
  log "Argo CD already installed. Skipping."
fi

wait_crd() {
  local crd="$1"
  until kubectl get crd "$crd" >/dev/null 2>&1; do sleep 2; done
  kubectl wait --for=condition=Established "crd/${crd}" --timeout=180s || true
}

log "Waiting for Argo CD CRDs to be Established ..."
wait_crd applications.argoproj.io
wait_crd applicationsets.argoproj.io
wait_crd appprojects.argoproj.io || true

log "Best-effort wait for argocd-server rollout ..."
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s || true

# Optional port-forward (commented). Uncomment if you want the web UI at :8080.
# log "Port-forwarding Argo CD UI :8080 -> svc/argocd-server:443"
# kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 8080:443
