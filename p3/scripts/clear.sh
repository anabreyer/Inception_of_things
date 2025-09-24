#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-iot-p3}"

echo "--- Deleting k3d cluster: $CLUSTER_NAME ---"
if k3d cluster get "$CLUSTER_NAME" &>/dev/null; then
  k3d cluster delete "$CLUSTER_NAME"
  echo "--- Cluster '$CLUSTER_NAME' deleted. ---"
else
  echo "--- Cluster '$CLUSTER_NAME' not found. ---"
fi

echo "--- Cleaning up Docker unused resources ---"
docker system prune -af || true
echo "--- Done ---"
