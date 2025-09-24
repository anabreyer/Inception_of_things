#!/usr/bin/env bash
set -euo pipefail

# Orchestrates the full p3 setup on a clean Debian/Ubuntu VM (no Vagrant required).

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$DIR")"

echo "== [1/4] Installing prerequisites =="
bash "$DIR/install.sh"

echo "== [2/4] Creating/Using k3d cluster =="
bash "$DIR/create_cluster.sh"

echo "== [3/4] Installing Argo CD =="
bash "$DIR/argocd.sh"

echo "== [4/4] Applying Argo CD Project & Application =="
kubectl apply -f "$ROOT/confs/project.yaml"
kubectl apply -f "$ROOT/confs/application.yaml"

echo "== Done =="
kubectl get applications -n argocd || true
echo "Test app (when Ready):   curl http://localhost:8888/"
