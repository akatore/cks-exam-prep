#!/usr/bin/env bash
# Run once on a practice cluster control-plane node (or laptop with kubectl).
# Installs common CKS lab CLIs if missing. Safe to re-run.
set -euo pipefail

echo "==> Checking kubectl..."
kubectl version --client 2>/dev/null || { echo "Install kubectl first."; exit 1; }
kubectl cluster-info

install_bom() {
  command -v bom >/dev/null && return
  echo "Installing bom (linux amd64)..."
  curl -fsSL -o /tmp/bom.tgz "https://github.com/kubernetes-sigs/bom/releases/latest/download/bom-linux-amd64.tar.gz"
  sudo tar -xzf /tmp/bom.tgz -C /usr/local/bin bom 2>/dev/null || tar -xzf /tmp/bom.tgz -C "$HOME/.local/bin" bom
  chmod +x /usr/local/bin/bom 2>/dev/null || chmod +x "$HOME/.local/bin/bom"
  export PATH="$HOME/.local/bin:$PATH"
}

install_trivy() {
  command -v trivy >/dev/null && return
  echo "Installing trivy..."
  curl -fsSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin
}

install_kube_bench() {
  command -v kube-bench >/dev/null && return
  echo "Installing kube-bench..."
  KVER=$(curl -L -s https://api.github.com/repos/aquasecurity/kube-bench/releases/latest | grep tag_name | cut -d'"' -f4)
  curl -fsSL -o /tmp/kube-bench.tar.gz "https://github.com/aquasecurity/kube-bench/releases/download/${KVER}/kube-bench_${KVER#v}_linux_amd64.tar.gz"
  sudo tar -xzf /tmp/kube-bench.tar.gz -C /usr/local/bin kube-bench
}

install_bom
install_trivy
install_kube_bench 2>/dev/null || echo "kube-bench: install manually on control-plane node if needed."

echo "==> Optional: Falco (Q1/Q4) — install on node if not present:"
echo "    curl -fsSL https://falco.org/repo/falcosecurity-4162ba11.gpg | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg"
echo "    See https://falco.org/docs/getting-started/installation/"

echo "==> Prereqs done. Use README-LAB-SETUP.md per-question scripts next."
