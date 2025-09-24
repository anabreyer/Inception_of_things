# Inception of Things

This repository contains the different parts of the **Inception of Things** project.

- `p1/` — Vagrant + K3s (2-node cluster)
- `p2/` — (to be added)
- `p3/` — (to be added)
- `bonus/` — (to be added)

---

## Part 1 — Vagrant + K3s (2-node cluster)

Two-VM lab using Vagrant + VirtualBox:

- **Server:** `aaduan-bS` → `192.168.56.110` (K3s server / control plane)  
- **Worker:** `aaduan-bSW` → `192.168.56.111` (K3s agent / worker)

> Host machine does **not** need `sudo`. Provisioning uses the `vagrant` user *inside* the VMs.

### Repo layout (for p1)

```
p1/
├─ Vagrantfile
└─ scripts/
   ├─ install_k3s_server.sh
   └─ install_k3s_worker.sh

```

### Prereqs

- VirtualBox (tested with 7.0.x)  
- Vagrant (tested with 2.4.x)

Optional (42-school style) preflight to change VirtualBox VM folder and add the box:

```bash
bash ~/set_vbox_folder_and_box.sh
```

### 1) Bring up the lab

From `p1/`:

```bash
# One-time, ensure scripts are executable
chmod +x scripts/*.sh

# Create both VMs and provision K3s
vagrant up
```

### 2) Quick checks

Hostnames:

```bash
vagrant ssh aaduan-bS  -c 'hostname'     # aaduan-bS
vagrant ssh aaduan-bSW -c 'hostname'     # aaduan-bSW
```

IPs:

```bash
vagrant ssh aaduan-bS  -c 'ip a | grep 192.168.56'
vagrant ssh aaduan-bSW -c 'ip a | grep 192.168.56'
```

Passwordless SSH:

```bash
ssh -i .vagrant/machines/aaduan-bS/virtualbox/private_key  vagrant@192.168.56.110 hostname
ssh -i .vagrant/machines/aaduan-bSW/virtualbox/private_key vagrant@192.168.56.111 hostname
```

K3s cluster state:

```bash
vagrant ssh aaduan-bS
kubectl get nodes -o wide
exit
```

### 3) Deeper verification

On **server**:

```bash
vagrant ssh aaduan-bS
systemctl status k3s --no-pager | head -20
kubectl get pods -n kube-system
kubectl get nodes -o wide
exit
```

On **worker**:

```bash
vagrant ssh aaduan-bSW
systemctl status k3s-agent --no-pager | head -20
exit
```

### 4) Handy kubectl smoke test

From the **server**:

```bash
vagrant ssh aaduan-bS
kubectl create deploy demo-nginx --image=nginx
kubectl expose deploy demo-nginx --port=80 --type=ClusterIP
kubectl get deploy,svc -o wide
kubectl delete svc/demo-nginx deploy/demo-nginx
exit
```

### 5) Troubleshooting

**Box import fails:** try `ubuntu/jammy64` or pin a version.

**Worker doesn’t join:**
```bash
vagrant ssh aaduan-bS -c 'sudo journalctl -u k3s -f'
vagrant ssh aaduan-bSW -c 'sudo journalctl -u k3s-agent -f'
```

**kubectl permission denied:**
```bash
vagrant ssh aaduan-bS
sudo chown vagrant:vagrant /etc/rancher/k3s/k3s.yaml
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
exit
```

### 6) Reset / clean

```bash
vagrant destroy -f
vagrant box remove bento/debian-11 --all
```

Reset VirtualBox machine folder (optional):

```bash
VBoxManage setproperty machinefolder "$HOME/VirtualBox VMs"
VBoxManage list systemproperties | grep "Default machine folder"
```

---

# Part 2 – K3s and Three Simple Applications

## 🎯 Goal
- Run 3 web applications inside **K3s** on the server VM (`192.168.56.110`).
- Route traffic to the apps based on the **Host** header:
  - `app1.com` → **app1**
  - `app2.com` → **app2** (**3 replicas**)
  - anything else → **app3** (default)

This part uses only the **server VM** (`aaduan-bS`) from Part 1.

---

## 📂 Files
All YAML manifests for this part are in the `p2/` folder:

- `namespace.yaml` → creates the `webapps` namespace
- `app1.yaml` → Deployment (1 replica) + Service for app1
- `app2.yaml` → Deployment (**3 replicas**) + Service for app2
- `app3.yaml` → Deployment (1 replica) + Service for app3
- `ingress.yaml` → Ingress with host-based rules + catch-all rule for app3

---

## ▶️ Steps

### 1) Boot server VM (host machine)
```bash
cd ~/inception-of-things/p1
vagrant up aaduan-bS
vagrant ssh aaduan-bS
```

### 2) Apply manifests (inside VM)
Option A (apply in order):
```bash
kubectl apply -f /project/p2/namespace.yaml
kubectl apply -f /project/p2/app1.yaml
kubectl apply -f /project/p2/app2.yaml
kubectl apply -f /project/p2/app3.yaml
kubectl apply -f /project/p2/ingress.yaml
```

Option B (apply folder twice):
```bash
kubectl apply -f /project/p2/
kubectl apply -f /project/p2/
```

### 3) Verify pods
```bash
kubectl get pods -n webapps -w
# expect: app1=1 pod, app2=3 pods, app3=1 pod
```

### 4) Verify services & ingress
```bash
kubectl get svc -n webapps
kubectl get endpoints -n webapps
kubectl describe ingress main-ingress -n webapps
```

---

## 🧪 Testing

### With curl (host machine)
```bash
curl -H "Host: app1.com"           http://192.168.56.110/
curl -H "Host: app2.com"           http://192.168.56.110/
curl -H "Host: something-else.com" http://192.168.56.110/
```

Expected:
- `app1.com` → app1 response
- `app2.com` → app2 response (scaled to 3 replicas)
- any other host → app3 response

### With browser (2 options)
1. **ModHeader extension (Chrome/Firefox):**
   - Add custom header: `Host: app1.com`
   - Visit `http://192.168.56.110/`
   - Switch Host header to `app2.com` or anything else for app3.

2. **nip.io domains (no sudo required):**
   - Update `ingress.yaml` to also include:
     - `app1.192.168.56.110.nip.io`
     - `app2.192.168.56.110.nip.io`
     - `app3.192.168.56.110.nip.io`
   - Then visit those directly in the browser.

---

## 🧹 Cleanup
```bash
kubectl delete -f /project/p2/
# or
kubectl delete namespace webapps
```

---

## ⚠️ Common issues
- **502 Bad Gateway**: Service has no endpoints → check `kubectl get endpoints -n webapps`
- **Ingress 404 for app3**: Traefik ignores `defaultBackend` → use a catch-all rule (no `host`) for app3
- **Host not resolving in browser**: use `ModHeader` or `nip.io` workaround if you can’t edit `/etc/hosts`


---

## Part 3 — (coming soon)

---

## Bonus — (coming soon)


p3/
├─ confs/
|   ├─ application.yaml
|   └─ project.yaml
├─ Dockerfile
└─ scripts/
   ├─ argocd.sh
   ├─ clear.sh
   ├─ create_cluster.sh
   ├─ install.sh
   ├─ setup.sh
   └─ vmsetting.sh


p3/confs/

application.yaml:
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: wil-playground
  namespace: argocd
spec:
  project: development
  source:
    repoURL: https://github.com/coisu/jischoi-Inception-of-Things-argoCD
    targetRevision: HEAD
    path: manifests           # deployment.yaml, ingress.yaml are exist on repo
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true

project.yaml:
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: development
  namespace: argocd
spec:
  description: Dev project
  sourceRepos:
    - https://github.com/coisu/jischoi-Inception-of-Things-argoCD.git
  destinations:
    - namespace: dev
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'

p3/scripts/

install.sh:
#!/usr/bin/env bash
set -euo pipefail

# =======================================
# install.sh
# Installs kubectl and k3d on a Linux system (Ubuntu/Debian recommended)
#
# Usage:
#   chmod +x install.sh
#   ./install.sh
#
# Make sure Docker is installed before running this script.
# =======================================

echo "== [1/2] Installing kubectl =="

# Download the latest stable version of kubectl
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
echo "Downloading kubectl version: ${KUBECTL_VERSION}"
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

# Install kubectl to /usr/local/bin
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

# Verify installation
if command -v kubectl >/dev/null 2>&1; then
  echo "kubectl installed successfully."
  kubectl version --client --output=yaml || true
else
  echo "Failed to install kubectl." >&2
  exit 1
fi

echo "== [2/2] Installing k3d =="

# Install k3d via official script
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Verify installation
if command -v k3d >/dev/null 2>&1; then
  echo "k3d installed successfully."
  k3d version || true
else
  echo "Failed to install k3d." >&2
  exit 1
fi

echo "== Installation complete =="
echo "You can now create a k3d cluster using, for example:"
echo "  k3d cluster create my-cluster --api-port 6443 -p \"8888:80@loadbalancer\" --agents 1"

create_cluster.sh:
#!/bin/bash

CLUSTER_NAME="my-cluster"


echo "--- Creating K3d cluster: $CLUSTER_NAME ---"
k3d cluster create $CLUSTER_NAME --api-port 6443 -p "8888:80@loadbalancer" --agents 1

echo "--- Waiting for cluster to be ready... ---"
sleep 15
kubectl wait --for=condition=Ready node --all --timeout=300s

# Create dev, argocd namespace [cite: 460]
echo "--- Creating namespaces: dev and argocd ---"
kubectl get ns dev    >/dev/null 2>&1 || kubectl create ns dev
kubectl get ns argocd >/dev/null 2>&1 || kubectl create ns argocd

echo "--- Cluster and namespaces are ready ---"
kubectl get nodes
kubectl get ns

echo "Cluster '$CLUSTER_NAME' is ready. Host http://localhost:8888 will reach Service port 80."

argocd.sh:
#!/bin/bash

# Insatall Argo CD
echo "--- Installing Argo CD into 'argocd' namespace ---"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "--- Waiting for Argo CD server to be ready... ---"
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# echo "--- To access the Argo CD UI, run the following command in a new terminal: ---"
# echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
# echo "--- Starting port-forwarding in the background... ---"
# kubectl port-forward svc/argocd-server -n argocd 8080:443 &


# getting default admin pw
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "-------------------------------------------------"
echo "Argo CD UI available at: https://localhost:8080"
echo "Username: admin"
echo "Password: $ADMIN_PASSWORD"
echo "-------------------------------------------------"

# kubectl port-forward svc/argocd-server -n argocd 8080:443 
echo "--- Port frorwarding... ---"
kubectl port-forward --address 0.0.0.0 svc/argocd-server -n argocd 8080:443


setup.sh:
#!/usr/bin/env bash
set -euo pipefail

echo "== [1/5] apt update/upgrade =="
sudo apt update -y
sudo apt upgrade -y

echo "== [2/5] tools =="
sudo apt install -y curl ca-certificates gnupg lsb-release vim git

echo "== [3/5] docker gpg key =="
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "== [4/5] docker repo (with fallback) =="
CODENAME="$(lsb_release -cs)"
USE="$CODENAME"
if ! curl -fsSL "https://download.docker.com/linux/debian/dists/${CODENAME}/Release" >/dev/null 2>&1; then
  USE="bookworm"
fi
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${USE} stable" \
 | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt update -y

echo "== [5/5] install docker =="
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

TARGET_USER="${SUDO_USER:-$USER}"
getent group docker >/dev/null || sudo groupadd docker
if id -nG "$TARGET_USER" | grep -qw docker; then
  echo "   -> ${TARGET_USER} already in docker group"
else
  echo "   -> add ${TARGET_USER} to docker group"
  sudo usermod -aG docker "$TARGET_USER"
  echo "      (re-login or run 'newgrp docker')"
fi

echo "== done =="
docker --version || true

vmsetting.sh:
#!/usr/bin/env bash
set -euo pipefail

VM="${VM_NAME:-p3}"
ISO_DIR="${ISO_DIR:-$HOME/goinfre}"
ISO="${ISO_PATH:-$HOME/goinfre/debian-13.1.0-amd64-netinst.iso}"

RAM_MB="${RAM_MB:-4096}"
CPUS="${CPUS:-2}"
DISK_GB="${DISK_GB:-20}"

# port forwarding
SSH_PORT="${SSH_PORT:-2222}"            # host 2222 -> guest 22
ARGO_PORT="${ARGO_PORT:-8080}"          # host 8080 -> guest 8080
APP_PORT="${APP_PORT:-8888}"            # host 8888 -> guest 8888
K8S_API_PORT="${K8S_API_PORT:-6443}"    # host 6443 -> guest 6443

VDI="$HOME/goinfre/VirtualBoxVMs/$VM/$VM.vdi"

if [[ ! -f "$ISO" ]]; then
  echo "[STEP] ISO not found, downloading..."
  mkdir -p "$ISO_DIR"
  wget -O "$ISO" \
    "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.1.0-amd64-netinst.iso"
else
  echo "[INFO] ISO already exists: $ISO"
fi

echo "[INFO] VM name: $VM"
echo "[INFO] ISO address: $ISO"
echo "[INFO] dick: $VDI"
echo "[INFO] memory: ${RAM_MB}MB, CPU: ${CPUS}, disk: ${DISK_GB}GB"
echo

# create vm
if ! VBoxManage showvminfo "$VM" >/dev/null 2>&1; then
  echo "[STEP] createvm"
  VBoxManage createvm --name "$VM" --register
else
  echo "[INFO] already exist: $VM"
fi

echo "[STEP] modifyvm (resouce/OS type)"
VBoxManage modifyvm "$VM" --memory "$RAM_MB" --cpus "$CPUS" --ostype "Debian_64"

echo "[STEP] Network (NAT + portforwarding)"
VBoxManage modifyvm "$VM" --nic1 nat

# initialize rules
for rule in ssh argo app k8sapi; do
  VBoxManage modifyvm "$VM" --natpf1 delete "$rule" 2>/dev/null || true
done

VBoxManage modifyvm "$VM" --natpf1 "ssh,tcp,127.0.0.1,${SSH_PORT},,22"
VBoxManage modifyvm "$VM" --natpf1 "argo,tcp,127.0.0.1,${ARGO_PORT},,8080"
VBoxManage modifyvm "$VM" --natpf1 "app,tcp,127.0.0.1,${APP_PORT},,8888"
VBoxManage modifyvm "$VM" --natpf1 "k8sapi,tcp,127.0.0.1,${K8S_API_PORT},,6443"

# storage controller
echo "[STEP] add storage controller"
if ! VBoxManage showvminfo "$VM" | grep -q '^Storage Controller Name.*SATA'; then
  VBoxManage storagectl "$VM" --name "SATA" --add sata --controller IntelAhci
fi

# create virtual disk
if [[ ! -f "$VDI" ]]; then
  echo "[STEP] virtual disk creation ${DISK_GB}GB"
  mkdir -p "$(dirname "$VDI")"
  VBoxManage createmedium disk --filename "$VDI" --size $(( DISK_GB * 1024 ))  # MB
fi

# iso - disk connection
VBoxManage storageattach "$VM" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "$VDI"
VBoxManage storageattach "$VM" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium "$ISO"

# boot dvd first
VBoxManage modifyvm "$VM" --boot1 dvd --boot2 disk

# boot vm
echo "[STEP] VM booting... "
VBoxManage startvm "$VM" --type gui

cat <<EOF

[process left]
1) Keep install Debian 13 with GUI
   - check "OpenSSH server" installation option
   - set user id and pw

2) when installion done and reboot, run commend below to seperate ISO
   VBoxManage storageattach "$VM" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium none

3) SSH conection test on local(host):
   ssh -p ${SSH_PORT} <username>@127.0.0.1

4) to access with key:
   ssh-keygen -t ed25519
   ssh-copy-id -p ${SSH_PORT} <username>@127.0.0.1

EOF

clear.sh:
#!/bin/bash

set -e

CLUSTER_NAME="my-cluster"

echo "--- Deleting K3d cluster: $CLUSTER_NAME... ---"
if k3d cluster get "$CLUSTER_NAME" &> /dev/null; then
    k3d cluster delete "$CLUSTER_NAME"
    echo "--- Cluster '$CLUSTER_NAME' deleted successfully. ---"
else
    echo "--- Cluster '$CLUSTER_NAME' not found. Skipping deletion. ---"
fi

echo ""
echo "--- Cleaning up Docker resources (unused containers, images, networks)... ---"
docker system prune -af
echo ""
echo "--- Environment has been cleared successfully! ---"

p3/

Dockerfile:
FROM debian:11

RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

RUN curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

WORKDIR /workspace

CMD ["tail", "-f", "/dev/null"]