# CKS Lab Setup — copy/paste scripts per question

Companion to [README_final.md](./README_final.md). **Does not replace** your practice README — use this only to **seed** scenarios on a cluster, then solve using the main doc.

| Item | Notes |
|------|--------|
| **Cluster** | minikube, kind, kubeadm lab, or KodeKloud/KillerCoda |
| **Where to run** | Each block says `kubectl` (any machine with kubeconfig) vs **node SSH** (control plane / worker) |
| **Scripts folder** | Same content as `lab-setup/*.sh` — run `bash lab-setup/q01-dev-mem.sh` if you prefer files |
| **Teardown** | `bash lab-setup/teardown-all.sh` removes most K8s namespaces |

---

## Before you start (optional tools)

<details>
<summary>00 — Install common CLIs (run once on lab VM)</summary>

**Where:** Linux VM with `curl` and `sudo`.

```bash
bash lab-setup/00-prereqs.sh
```

Or paste:

```bash
set -euo pipefail
command -v kubectl >/dev/null || { echo "Install kubectl"; exit 1; }
kubectl cluster-info
# bom
if ! command -v bom >/dev/null; then
  curl -fsSL -o /tmp/bom.tgz "https://github.com/kubernetes-sigs/bom/releases/latest/download/bom-linux-amd64.tar.gz"
  sudo tar -xzf /tmp/bom.tgz -C /usr/local/bin bom && sudo chmod +x /usr/local/bin/bom
fi
# trivy
if ! command -v trivy >/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin
fi
echo "Done. Install Falco on nodes separately for Q1/Q4 if needed."
```

</details>

---

## OP questions (thread)

### Q1 — `/dev/mem` (cpu / gpu / nvidia)

**Scenario:** Namespace `workloads` has Deployments `cpu`, `gpu`, `nvidia` — same image `busybox:1.36`, all **privileged**. Only **`cpu`** periodically reads `/dev/mem`.

**Your tasks:** Find the Deployment accessing `/dev/mem` → scale it to `0`.

<details>
<summary>Setup script — copy & paste (kubectl)</summary>

```bash
set -euo pipefail
NS=workloads
IMG=busybox:1.36

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

for dep in cpu gpu nvidia; do
  if [[ "$dep" == "cpu" ]]; then
    ACCESS='while true; do head -c 1 /dev/mem 2>/dev/null || true; sleep 5; done'
  else
    ACCESS='sleep infinity'
  fi
  kubectl -n "$NS" create deployment "$dep" --image="$IMG" --replicas=1 \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n "$NS" patch deployment "$dep" --type=json -p='[
    {"op":"replace","path":"/spec/template/spec/containers/0/securityContext","value":{"privileged":true}},
    {"op":"replace","path":"/spec/template/spec/containers/0/command","value":["sh","-c"]},
    {"op":"replace","path":"/spec/template/spec/containers/0/args","value":["'"$ACCESS"'"]}
  ]'
done

kubectl -n "$NS" rollout status deployment/cpu --timeout=120s
kubectl get pods -n "$NS" -o wide
echo "Practice: identify offender, then: kubectl scale deployment cpu -n workloads --replicas=0"
```

</details>

<details>
<summary>Teardown</summary>

```bash
kubectl delete namespace workloads --ignore-not-found
```

</details>

---

### Q2 — libcrypto + `bom` (three container tags)

**Scenario:** Namespace `supply-chain`, Deployment `triple-app` with containers `app-a` / `app-b` / `app-c` using `alpine:3.18.5`, `alpine:3.19.1`, `alpine:3.20.3`. Find which image has the target **libcrypto** (use `bom` + `grep`; thread example `3.1.4` — adjust grep to your brief).

**Your tasks:** Identify tag → `bom generate --image … --output report.spdx`.

<details>
<summary>Setup script — copy & paste (kubectl)</summary>

```bash
set -euo pipefail
NS=supply-chain

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: triple-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: triple-app
  template:
    metadata:
      labels:
        app: triple-app
    spec:
      containers:
        - name: app-a
          image: alpine:3.18.5
          command: ["sleep", "infinity"]
        - name: app-b
          image: alpine:3.19.1
          command: ["sleep", "infinity"]
        - name: app-c
          image: alpine:3.20.3
          command: ["sleep", "infinity"]
EOF

kubectl -n "$NS" rollout status deployment/triple-app --timeout=120s
kubectl get pod -n "$NS" -o jsonpath='{range .items[0].spec.containers[*]}{.name}{"\t"}{.image}{"\n"}{end}'
echo 'Practice: for img in alpine:3.18.5 alpine:3.19.1 alpine:3.20.3; do bom generate --image $img | grep -i libcrypto; done'
```

</details>

<details>
<summary>Teardown</summary>

```bash
kubectl delete namespace supply-chain --ignore-not-found
```

</details>

---

### Q3 — `developer` in `docker` group + Docker TCP

**Scenario:** User **`developer`** is in group **`docker`**. Docker listens on **`tcp://0.0.0.0:2375`** (practice VM only).

**Your tasks:** `gpasswd -d developer docker` → remove TCP from `daemon.json` / `docker.socket` → restart Docker.

<details>
<summary>Setup script — copy & paste (node SSH, practice VM only)</summary>

```bash
set -euo pipefail
sudo useradd -m -s /bin/bash developer 2>/dev/null || true
sudo usermod -aG docker developer

sudo mkdir -p /etc/docker
sudo cp -a /etc/docker/daemon.json /etc/docker/daemon.json.bak-cks 2>/dev/null || true
echo '{"hosts":["unix:///var/run/docker.sock","tcp://0.0.0.0:2375"]}' | sudo tee /etc/docker/daemon.json

SOCKET=/usr/lib/systemd/system/docker.socket
if [[ -f "$SOCKET" ]]; then
  sudo cp -a "$SOCKET" "${SOCKET}.bak-cks" 2>/dev/null || true
  grep -q 'tcp://0.0.0.0:2375' "$SOCKET" || \
    sudo sed -i 's|ExecStart=/usr/bin/dockerd -H fd://|ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375|' "$SOCKET"
fi

sudo systemctl daemon-reload
sudo systemctl restart docker || echo "If hang: fix JSON after lab"
groups developer
ss -lntp | grep 2375 || true
```

</details>

<details>
<summary>Teardown (restore Docker)</summary>

```bash
sudo mv /etc/docker/daemon.json.bak-cks /etc/docker/daemon.json 2>/dev/null || \
  echo '{"hosts":["unix:///var/run/docker.sock"]}' | sudo tee /etc/docker/daemon.json
sudo mv /usr/lib/systemd/system/docker.socket.bak-cks /usr/lib/systemd/system/docker.socket 2>/dev/null || true
sudo systemctl daemon-reload && sudo systemctl restart docker
```

</details>

---

## Additional scenarios

### Q4 — Falco custom rule for `/dev/mem`

**Scenario:** Same as Q1 (run Q1 setup first). Falco installed on the **node**; default rules do not alert on `/dev/mem`.

**Your tasks:** Write rule with `fd.name = /dev/mem` → `falco -U` or `falco -r …` → scale offender.

<details>
<summary>Setup script — copy & paste</summary>

**Step 1 — Kubernetes (if not done):** use **Q1** setup script above.

**Step 2 — Node (install Falco if missing, Ubuntu/Debian example):**

```bash
# On node — adjust for your distro; see https://falco.org/docs/getting-started/installation/
curl -fsSL https://falco.org/repo/falcosecurity-4162ba11.gpg | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | sudo tee /etc/apt/sources.list.d/falcosecurity.list
sudo apt-get update && sudo apt-get install -y falco

sudo tee /etc/falco/falco_rules.local.yaml <<'EOF'
- rule: Dev mem access
  desc: Practice rule for /dev/mem
  condition: open_read and fd.name = /dev/mem
  output: "dev/mem (user=%user.name container=%container.name k8s.pod=%k8s.pod.name)"
  priority: WARNING
EOF
echo "Practice: sudo falco -U   OR   sudo falco -r /etc/falco/falco_rules.local.yaml"
```

</details>

---

### Q5 — Trivy + `bom` on multiple images

**Scenario:** Three public images with different patch levels; find HIGH/CRITICAL and libcrypto via Trivy/`bom`.

**Your tasks:** Scan → pick unsafe tag → document fix.

<details>
<summary>Setup script — copy & paste (kubectl + CLI)</summary>

```bash
set -euo pipefail
NS=trivy-lab
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
for tag in 3.18.5 3.19.1 3.20.3; do
  kubectl -n "$NS" run "alpine-${tag//./-}" --image="alpine:${tag}" --restart=Never --command -- sleep 3600
done
kubectl get pods -n "$NS"
echo "Practice:"
echo "  trivy image --severity HIGH,CRITICAL alpine:3.18.5"
echo "  bom generate --image alpine:3.19.1 | grep -i libcrypto"
```

</details>

<details>
<summary>Teardown</summary>

```bash
kubectl delete namespace trivy-lab --ignore-not-found
```

</details>

---

### Q6 — kube-bench CIS failures

**Scenario:** Control-plane node intentionally misconfigured for CIS checks (anonymous auth, etcd ownership). **Practice cluster only.**

**Your tasks:** `kube-bench run --targets master,node` → fix listed FAILs → re-run.

<details>
<summary>Setup script — copy & paste (control-plane node SSH only)</summary>

```bash
# WARNING: practice cluster only
set -euo pipefail
APISERVER=/etc/kubernetes/manifests/kube-apiserver.yaml
sudo cp -a "$APISERVER" "${APISERVER}.bak-cks-lab"

# Ensure anonymous auth is ON (bad)
sudo grep -q 'anonymous-auth=true' "$APISERVER" || \
  sudo sed -i 's|--anonymous-auth=false|--anonymous-auth=true|g' "$APISERVER" || \
  sudo sed -i '/- kube-apiserver/a\    - --anonymous-auth=true' "$APISERVER"

# etcd dir world-readable group (example misconfig)
sudo mkdir -p /var/lib/etcd
sudo chown root:root /var/lib/etcd 2>/dev/null || true

echo "Wait ~60s for static pod restart, then on node:"
echo "  sudo kube-bench run --targets master,node"
echo "Restore after: sudo mv ${APISERVER}.bak-cks-lab $APISERVER"
```

</details>

---

### Q7 — API server audit logging

**Scenario:** Auditing not configured. You must add policy + log path on `kube-apiserver` and log **namespaces** at **RequestResponse**.

<details>
<summary>Setup script — copy & paste (control-plane node SSH)</summary>

```bash
# Creates policy file only — YOU complete kube-apiserver mounts/flags (exam skill)
set -euo pipefail
sudo tee /etc/kubernetes/audit-policy.yaml <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: Metadata
    omitStages: ["RequestReceived"]
EOF
sudo mkdir -p /var/log/kubernetes/audit
sudo chmod 700 /var/log/kubernetes/audit
echo "Practice: add --audit-policy-file and --audit-log-path to kube-apiserver.yaml"
echo "Add RequestResponse rule for namespaces resources, then: kubectl get ns && sudo tail /var/log/kubernetes/audit/audit.log"
```

</details>

---

### Q8 — ImagePolicyWebhook (partial config)

**Scenario:** Webhook kubeconfig exists but admission plugin not wired. Complete `admission-config.yaml` + API server flags.

<details>
<summary>Setup script — copy & paste (control-plane)</summary>

```bash
set -euo pipefail
sudo mkdir -p /etc/kubernetes/imagepolicy-webhook
sudo tee /etc/kubernetes/admission-config.yaml <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins: []
EOF
sudo tee /etc/kubernetes/imagepolicywebhook.kubeconfig <<'EOF'
apiVersion: v1
kind: Config
# INCOMPLETE — practice completing clusters/servers/certs per docs
current-context: webhook
contexts: []
clusters: []
users: []
EOF
echo "Practice: fill ImagePolicyWebhook plugin + kubeconfig; enable on kube-apiserver"
echo "Docs: https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#imagepolicywebhook"
```

</details>

---

### Q9 — Missing admission plugins

**Scenario:** `kube-apiserver` manifest available; enable full plugin list from brief.

<details>
<summary>Setup script — copy & paste (control-plane node SSH)</summary>

```bash
APISERVER=/etc/kubernetes/manifests/kube-apiserver.yaml
sudo cp -a "$APISERVER" "${APISERVER}.bak-cks-q9"
sudo grep enable-admission-plugins "$APISERVER" || echo "No line yet — add --enable-admission-plugins=..."
echo "Practice: add NodeRestriction,NamespaceLifecycle,LimitRanger,ServiceAccount,..."
echo "Restore: sudo mv ${APISERVER}.bak-cks-q9 $APISERVER"
```

</details>

---

### Q10 — Pod Security Admission (restricted)

**Scenario:** Namespace `psa-lab` enforces **restricted**. Deployment `broken-app` is privileged → Pods won't run.

**Your tasks:** Fix Deployment only (not namespace labels).

<details>
<summary>Setup script — copy & paste (kubectl)</summary>

```bash
set -euo pipefail
NS=psa-lab
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "$NS" \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  --overwrite

kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: broken-app
  template:
    metadata:
      labels:
        app: broken-app
    spec:
      containers:
        - name: app
          image: nginx:alpine
          securityContext:
            privileged: true
            allowPrivilegeEscalation: true
EOF
kubectl get pods -n "$NS"
echo "Practice: kubectl edit deployment broken-app -n psa-lab until Running"
```

</details>

<details>
<summary>Teardown</summary>

```bash
kubectl delete namespace psa-lab --ignore-not-found
```

</details>

---

### Q11 — ServiceAccount projected token

**Scenario A:** Deployment `token-app` in `sa-lab` — add projected SA token at `/var/run/secrets/custom-tokens/token`.  
**Scenario B:** SA `my-sa` with `automountServiceAccountToken: false`.

<details>
<summary>Setup script — copy & paste (kubectl)</summary>

```bash
set -euo pipefail
NS=sa-lab
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" create serviceaccount my-sa --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: token-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: token-app
  template:
    metadata:
      labels:
        app: token-app
    spec:
      serviceAccountName: my-sa
      containers:
        - name: app
          image: nginx:alpine
EOF
echo "Practice: add projected volume + mount; optional: patch SA automountServiceAccountToken: false"
```

</details>

---

### Q12 — NetworkPolicy default deny

**Scenario:** `team-a` has `backend` (nginx); `team-b` has `frontend` + `tester` (netshoot). No policies yet.

**Your tasks:** Default deny all → allow DNS → allow ingress from `team-b` label `role=frontend`.

<details>
<summary>Setup script — copy & paste (kubectl)</summary>

```bash
set -euo pipefail
for ns in team-a team-b; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
kubectl label namespace team-b role=frontend --overwrite

kubectl -n team-a create deployment backend --image=nginx:alpine
kubectl -n team-a label deployment backend app=backend --overwrite
kubectl -n team-b create deployment frontend --image=busybox:1.36 -- sleep infinity
kubectl -n team-b label deployment frontend role=frontend --overwrite
kubectl -n team-a expose deployment backend --port=80
kubectl -n team-b run tester --image=nicolaka/netshoot --restart=Never -- sleep 3600

kubectl get pods -n team-a && kubectl get pods -n team-b
echo "Practice: NetworkPolicies in team-a (default deny + DNS + selective ingress)"
```

</details>

<details>
<summary>Teardown</summary>

```bash
kubectl delete namespace team-a team-b --ignore-not-found
```

</details>

---

### Q13 — CiliumNetworkPolicy

**Scenario:** Cilium CNI; namespace `app` backend must accept traffic from namespace `trusted` and from **host**.

**Prerequisite:** Cilium installed (`cilium version`).

<details>
<summary>Setup script — copy & paste (kubectl)</summary>

```bash
set -euo pipefail
# Install Cilium if missing (kind example — adjust for your cluster):
# cilium install

for ns in app trusted; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done
kubectl -n app run backend --image=nginx:alpine --labels=app=backend
kubectl -n trusted run client --image=busybox:1.36 --command -- sleep infinity

echo "Practice: CiliumNetworkPolicy on backend in app — fromEndpoints trusted + fromEntities host"
kubectl get pods -n app -n trusted 2>/dev/null || kubectl get pods -A | grep -E 'app|trusted'
```

</details>

---

### Q14 — Istio sidecar + STRICT mTLS

**Scenario:** Namespace `foo` with `httpbin`; enable injection + `PeerAuthentication` STRICT.

**Prerequisite:** Istio installed.

<details>
<summary>Setup script — copy & paste (kubectl)</summary>

```bash
set -euo pipefail
# Install: istioctl install --set profile=demo -y   (if needed)

NS=foo
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" apply -f https://raw.githubusercontent.com/istio/istio/release-1.22/samples/httpbin/httpbin.yaml
kubectl -n "$NS" rollout status deployment/httpbin --timeout=180s

echo "Practice:"
echo "  kubectl label namespace foo istio-injection=enabled --overwrite"
echo "  kubectl rollout restart deployment -n foo"
echo "  Apply PeerAuthentication mode: STRICT in foo"
```

</details>

---

### Q15 — Worker node upgrade (kubeadm)

**Scenario:** Multi-node kubeadm cluster; control plane already at target version; upgrade **one worker**.

**Note:** Cannot be fully scripted on minikube. Use a real kubeadm lab.

<details>
<summary>Setup checklist (manual lab)</summary>

```bash
kubectl get nodes -o wide
# On worker: apt-cache madison kubeadm
# Practice: drain → apt install kubeadm/kubelet/kubectl → kubeadm upgrade node → uncordon
```

</details>

---

### Q16 — Disable anonymous API access

**Scenario:** API server has `--anonymous-auth=true` (misconfig). Set to `false`.

<details>
<summary>Setup script — copy & paste (control-plane node SSH, practice only)</summary>

```bash
APISERVER=/etc/kubernetes/manifests/kube-apiserver.yaml
sudo cp -a "$APISERVER" "${APISERVER}.bak-cks-q16"
sudo sed -i 's|--anonymous-auth=false|--anonymous-auth=true|g' "$APISERVER" || \
  sudo sed -i '/- kube-apiserver/a\    - --anonymous-auth=true' "$APISERVER"
echo "Practice: set --anonymous-auth=false and verify"
```

</details>

---

### Q17 — etcd encryption at rest

**Scenario:** Secrets stored unencrypted; add `EncryptionConfiguration` to API server.

<details>
<summary>Setup script — copy & paste (control-plane)</summary>

```bash
sudo tee /etc/kubernetes/encryption-config.yaml <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources: [secrets]
    providers:
      - identity: {}
EOF
kubectl create secret generic enc-test -n default --from-literal=key=value --dry-run=client -o yaml | kubectl apply -f -
echo "Practice: add aescbc key + --encryption-provider-config on kube-apiserver; re-encrypt secrets"
```

</details>

---

### Q18 — Ingress TLS + HTTPS redirect

**Scenario:** Namespace `ingress-lab`, app `web`, TLS secret `app-tls` exists, Ingress **without** TLS/redirect (you fix).

<details>
<summary>Setup script — copy & paste (kubectl)</summary>

```bash
set -euo pipefail
NS=ingress-lab
HOST=app.cks-lab.local

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

TMP=$(mktemp -d)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$TMP/tls.key" -out "$TMP/tls.crt" -subj "/CN=${HOST}"
kubectl -n "$NS" create secret tls app-tls --cert="$TMP/tls.crt" --key="$TMP/tls.key"
rm -rf "$TMP"

kubectl -n "$NS" create deployment web --image=nginx:alpine
kubectl -n "$NS" expose deployment web --port=80
kubectl -n "$NS" apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx
  rules:
    - host: ${HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
EOF
echo "Install ingress-nginx if needed. Practice: add tls: + ssl-redirect annotations"
```

</details>

---

### Q19 — RuntimeClass (gVisor / Kata)

**Scenario:** Create `RuntimeClass` and Deployment using it (handler must exist on nodes).

<details>
<summary>Setup script — copy & paste (kubectl)</summary>

```bash
kubectl apply -f - <<'EOF'
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sandbox-test
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sandbox-test
  template:
    metadata:
      labels:
        app: sandbox-test
    spec:
      runtimeClassName: gvisor
      containers:
        - name: app
          image: nginx:alpine
EOF
echo "If Pending: handler runsc not on node — practice finding handler via crictl info"
```

</details>

---

### Q20 — Container immutability

**Scenario:** Deployment `mutable-app` in `immutability-lab` without `readOnlyRootFilesystem`.

<details>
<summary>Setup script — copy & paste (kubectl)</summary>

```bash
set -euo pipefail
NS=immutability-lab
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" create deployment mutable-app --image=nginx:alpine
echo "Practice: patch securityContext readOnlyRootFilesystem + emptyDir for /tmp"
```

</details>

---

### Q21 — Dockerfile one-line fix

**Scenario:** Insecure Dockerfile on disk (`USER root`, secret in `ENV`).

<details>
<summary>Setup script — copy & paste (any Linux shell)</summary>

```bash
DIR=/tmp/cks-lab/q21
mkdir -p "$DIR"
cat > "$DIR/Dockerfile" <<'EOF'
FROM alpine:3.19
ENV API_TOKEN=super-secret-do-not-commit
RUN apk add --no-cache curl
USER root
CMD ["sleep", "infinity"]
EOF
echo "File: $DIR/Dockerfile — fix exactly ONE line (e.g. USER nobody)"
```

</details>

---

### Q22 — Deployment one-line fix

**Scenario:** `insecure-deploy` in `static-lab`: password in `env`, `privileged: true`.

<details>
<summary>Setup script — copy & paste (kubectl)</summary>

```bash
set -euo pipefail
NS=static-lab
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: insecure-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: insecure
  template:
    metadata:
      labels:
        app: insecure
    spec:
      containers:
        - name: app
          image: nginx:1.25
          env:
            - name: DB_PASSWORD
              value: "P@ssw0rd123"
          securityContext:
            privileged: true
EOF
echo "Practice: kubectl edit deployment insecure-deploy -n static-lab — ONE line only"
```

</details>

---

### Q23 — Platform binary verification

**Scenario:** Practice verifying official Kubernetes release checksums.

<details>
<summary>Setup script — copy & paste (lab VM)</summary>

```bash
set -euo pipefail
VER=1.29.2
cd /tmp/cks-lab/q23
mkdir -p /tmp/cks-lab/q23 && cd /tmp/cks-lab/q23
curl -fsSLO "https://dl.k8s.io/release/v${VER}/bin/linux/amd64/kubectl"
curl -fsSLO "https://dl.k8s.io/release/v${VER}/bin/linux/amd64/kubectl.sha256"
echo "Practice: sha256sum -c kubectl.sha256"
echo "Compare with: sha256sum /usr/bin/kubectl"
```

</details>

---

### Q24 — OPA Gatekeeper

**Scenario:** Install Gatekeeper; apply partial `ConstraintTemplate` — you finish Constraint.

<details>
<summary>Setup script — copy & paste (kubectl)</summary>

```bash
set -euo pipefail
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.17.1/deploy/gatekeeper.yaml
kubectl wait --for=condition=available --timeout=180s \
  deployment/gatekeeper-controller-manager -n gatekeeper-system

kubectl apply -f - <<'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          not input.review.object.metadata.labels.app
          msg := "label 'app' is required"
        }
EOF
echo "Practice: create K8sRequiredLabels Constraint; test bad/good pods"
```

</details>

---

## Teardown everything (Kubernetes)

<details>
<summary>Global teardown script</summary>

```bash
bash lab-setup/teardown-all.sh
```

Or:

```bash
for ns in workloads supply-chain psa-lab team-a team-b sa-lab ingress-lab immutability-lab static-lab trivy-lab foo trusted app; do
  kubectl delete namespace "$ns" --ignore-not-found --timeout=60s
done
kubectl delete deployment sandbox-test --ignore-not-found 2>/dev/null || true
```

Restore control-plane manifests from `*.bak-cks*` if you ran Q6/Q9/Q16 setup on nodes.

</details>

---

## Quick map

| Q | Namespace / scope | Script file |
|---|-------------------|-------------|
| 1 | `workloads` | `lab-setup/q01-dev-mem.sh` |
| 2 | `supply-chain` | `lab-setup/q02-libcrypto-bom.sh` |
| 3 | node Docker | `lab-setup/q03-docker-tcp.sh` |
| 10 | `psa-lab` | `lab-setup/q10-psa-restricted.sh` |
| 11 | `sa-lab` | `lab-setup/q11-sa-projected.sh` |
| 12 | `team-a`, `team-b` | `lab-setup/q12-networkpolicy.sh` |
| 18 | `ingress-lab` | `lab-setup/q18-ingress-tls.sh` |
| 20–22 | various | `q20`–`q22` scripts |

Questions **6–9, 15–17** are control-plane / kubeadm labs — use inline scripts only on disposable clusters.

---

*Practice only. Pair with [README_final.md](./README_final.md) for tasks and solutions.*
