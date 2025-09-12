#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# Part 3 bootstrap script (IDEMPOTENT, ZERO manual steps)
# - Installs Docker, kubectl, k3d (only if missing)
# - If current shell can't access Docker, transparently uses sudo for Docker/k3d
# - Creates (or reuses) a k3d cluster
# - Writes kubeconfig for *this user* and switches kubectl context
# - Ensures namespaces exist
# - Installs Argo CD if missing + waits for CRDs to be Established
# ------------------------------------------------------------------------------

CLUSTER="iot-p3"

log(){ printf "\n[BOOTSTRAP] %s\n" "$*"; }

# --- Base packages ------------------------------------------------------------
log "Installing base packages (safe to re-run)..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release git jq

# --- Docker -------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  log "Docker not found. Installing Docker Engine (official repo)..."
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  # add user to docker group (future sessions), but we won't require it now
  sudo usermod -aG docker "$USER" || true
fi

# If this shell can't talk to docker, we will run docker/k3d via sudo
if docker info >/dev/null 2>&1; then
  SUDO_DOCKER=""
  log "Docker socket accessible by current user."
else
  SUDO_DOCKER="sudo "
  log "Docker socket NOT accessible; will use sudo for Docker/k3d commands."
  ${SUDO_DOCKER}docker ps >/dev/null 2>&1 || { echo "FATAL: sudo docker not working"; exit 1; }
fi

# --- kubectl ------------------------------------------------------------------
if ! command -v kubectl >/dev/null 2>&1; then
  log "kubectl not found. Installing..."
  K_VER="$(curl -s https://dl.k8s.io/release/stable.txt)"
  curl -LO "https://dl.k8s.io/release/${K_VER}/bin/linux/amd64/kubectl"
  sudo install -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
else
  log "kubectl already installed. Skipping."
fi

# --- k3d ----------------------------------------------------------------------
if ! command -v k3d >/dev/null 2>&1; then
  log "k3d not found. Installing..."
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | sudo bash
else
  log "k3d already installed. Skipping."
fi

# Helper to run k3d (with sudo if required)
k3d_cmd() { ${SUDO_DOCKER}k3d "$@"; }

# --- k3d Cluster --------------------------------------------------------------
if ! k3d_cmd cluster list | grep -q "^${CLUSTER}\b"; then
  log "Creating k3d cluster '${CLUSTER}' (1 server, 1 agent, LB: 8888->80)..."
  k3d_cmd cluster create "${CLUSTER}" \
    --servers 1 --agents 1 \
    --api-port 6550 \
    --port "8888:80@loadbalancer"
else
  log "k3d cluster '${CLUSTER}' already exists. Skipping create."
fi

# --- Kubeconfig (write for THIS user; no merge needed on fresh VM) ------------
log "Writing kubeconfig for user '${USER}' and switching context..."
mkdir -p "$HOME/.kube"
k3d_cmd kubeconfig get "${CLUSTER}" > "$HOME/.kube/config"
# ensure correct ownership when k3d ran as root
chown "$USER":"$USER" "$HOME/.kube/config" || true

# Switch to the expected context
if kubectl config get-contexts -o name | grep -q "^k3d-${CLUSTER}$"; then
  kubectl config use-context "k3d-${CLUSTER}"
else
  log "WARNING: context 'k3d-${CLUSTER}' not found. Available contexts are:"
  kubectl config get-contexts
  # try first k3d-* context
  ALT_CTX="$(kubectl config get-contexts -o name | grep '^k3d-' | head -n1 || true)"
  [ -n "${ALT_CTX}" ] && kubectl config use-context "${ALT_CTX}" || true
fi

# --- Namespaces ---------------------------------------------------------------
log "Ensuring namespaces exist..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev     --dry-run=client -o yaml | kubectl apply -f -

# --- Argo CD ------------------------------------------------------------------
if ! kubectl get deploy -n argocd argocd-server >/dev/null 2>&1; then
  log "Installing Argo CD (CRDs + controllers)..."
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
else
  log "Argo CD appears installed. Skipping install."
fi

# Wait for CRDs to be Established (so Application kind is usable)
wait_crd() {
  local crd="$1"
  until kubectl get crd "$crd" >/dev/null 2>&1; do sleep 2; done
  kubectl wait --for=condition=Established --timeout=180s "crd/${crd}" || true
}
log "Waiting for Argo CD CRDs to be Established..."
wait_crd applications.argoproj.io
wait_crd applicationsets.argoproj.io
wait_crd appprojects.argoproj.io || true
wait_crd apprprojects.argoproj.io || true

# Best-effort: wait for argocd-server
log "Waiting (best-effort) for argocd-server rollout..."
kubectl -n argocd rollout status deploy/argocd-server --timeout=180s || true

log "Bootstrap complete. You can now apply your Argo Application file."
