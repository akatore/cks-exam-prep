#!/usr/bin/env bash
# Run on a Linux node with Docker (practice VM only — misconfigures Docker TCP).
set -euo pipefail

sudo useradd -m -s /bin/bash developer 2>/dev/null || true
sudo usermod -aG docker developer

sudo mkdir -p /etc/docker
if [[ ! -f /etc/docker/daemon.json.bak-cks ]]; then
  sudo cp -a /etc/docker/daemon.json /etc/docker/daemon.json.bak-cks 2>/dev/null || true
fi
echo '{"hosts":["unix:///var/run/docker.sock","tcp://0.0.0.0:2375"]}' | sudo tee /etc/docker/daemon.json

SOCKET=/usr/lib/systemd/system/docker.socket
if [[ -f "$SOCKET" ]] && [[ ! -f "${SOCKET}.bak-cks" ]]; then
  sudo cp -a "$SOCKET" "${SOCKET}.bak-cks"
  sudo sed -i 's|-H tcp://0.0.0.0:2375||g' "$SOCKET" 2>/dev/null || true
  # Ensure TCP is present for lab (some distros use socket unit only)
  sudo sed -i 's|ExecStart=.*dockerd|ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375|' "$SOCKET" 2>/dev/null || true
fi

sudo systemctl daemon-reload
sudo systemctl restart docker || echo "If restart hangs, fix daemon.json after practice."

echo "Lab ready: user developer in group docker; TCP 2375 may be enabled."
groups developer
ss -lntp 2>/dev/null | grep 2375 || netstat -lntp 2>/dev/null | grep 2375 || true
