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
