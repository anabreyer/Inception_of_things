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

## Part 2 — (coming soon)

---

## Part 3 — (coming soon)

---

## Bonus — (coming soon)
