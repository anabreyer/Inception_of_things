#!/usr/bin/env bash
set -euo pipefail

TARGET_BASE="/goinfre/$(whoami)"
TARGET_DIR="$TARGET_BASE/VirtualBoxVMs"

echo "==> Ensuring target folder exists: $TARGET_DIR"
mkdir -p "$TARGET_DIR"

echo "==> Setting VirtualBox default machine folder..."
VBoxManage setproperty machinefolder "$TARGET_DIR"

echo "==> Verifying:"
VBoxManage list systemproperties | grep -E "Default machine folder|machinefolder" || true

echo "==> Making sure the Debian box is available (bento/debian-11)..."
if ! vagrant box list | grep -q "^bento/debian-11"; then
  vagrant box add bento/debian-11
else
  echo "    bento/debian-11 already present."
fi

echo "All set. Now run:  cd ~/inception-of-things/p1 && vagrant up"
