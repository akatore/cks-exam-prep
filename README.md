# CKS Practice Questions (r/kubernetes thread)

Scenarios distilled from [Helping with understanding some Questions](https://www.reddit.com/r/kubernetes/) (archived thread; local copy: `Helping with understanding some Questions _ r_kubernetes.PDF`). These mirror **reported** task types—not verbatim exam prompts.

**How to use:** Set up minikube, kind, KillerCoda, or KodeKloud. Solve each section without expanding **Solution**. Use docs search the way you would in the exam.

**Thread exam tips:** ~16 tasks / ~2 hours; flag hard items and return later; terminal copy/paste: `Ctrl+Shift+C` / `Ctrl+Shift+V`; practice Falco, `bom`, Trivy, kube-bench, `kubeadm`, Istio basics, and Kubernetes documentation navigation.

---

## OP — three questions reported most often

### 1. Runtime — which Deployment accesses `/dev/mem`?

**Scenario:** Namespace `workloads` has Deployments `cpu`, `gpu`, and `nvidia`. All use the **same container image**. Pod YAML may show `securityContext.privileged: true` on **all** of them. **One** workload is accessing host device `/dev/mem`. The brief may mention Falco.

**Tasks:**
1. Identify which Deployment’s Pod is accessing `/dev/mem`.
2. Scale that Deployment to `0` replicas.

**Skills:** Falco custom rules (`fd.name`, `open_read`), `kubectl scale`, node inspection (`ps`, `lsof`), comparing Pod/Deployment manifests.

<details>
<summary>Solution</summary>

**Reported answer:** Deployment **`cpu`**.

#### A — Falco custom rule (intended when Falco is mentioned)

```bash
kubectl get deploy,pods -n workloads -o wide
```

Add a local rule (e.g. `/etc/falco/falco_rules.local.yaml` or pass with `-r`):

```yaml
- rule: Detect dev mem access
  desc: Detect access to /dev/mem
  condition: open_read and fd.name = /dev/mem
  output: "Access to /dev/mem (user=%user.name container=%container.name k8s.pod=%k8s.pod.name)"
  priority: WARNING
```

Run Falco (thread variants):

```bash
sudo falco -U
# or
sudo falco -r /etc/falco/falco_rules.local.yaml
```

Read logs for `k8s.pod` / container → map to Deployment → scale:

```bash
kubectl scale deployment cpu -n workloads --replicas=0
```

If Falco produces **no output**, enable `file_output` / syslog in `falco.yaml`, or use B/C below. Thread reports: default rules may not log `/dev/mem`; copying an existing file-read rule and changing `fd.name` is enough.

#### B — Node process inspection (when Falco is broken or not installed)

```bash
sudo ps aux | grep /dev/mem
# or
sudo lsof /dev/mem
```

Map PID → container (`crictl ps`, `docker ps` + inspect) → Pod → Deployment. Consensus: **`cpu`**.

#### C — Manifest / behavior diff

```bash
kubectl get pods -n workloads -o yaml | grep -A10 securityContext
kubectl describe pod -n workloads -l app=cpu
```

`exec` into each container only confirms **capability** to access `/dev/mem` when all are privileged—not which one **is** accessing it. Prefer runtime evidence (Falco or `ps`/`lsof`).

</details>

---

### 2. Supply chain — libcrypto version + SPDX SBOM (`bom`)

**Scenario:** A Pod runs **three containers** from the **same image repository** with **different tags**. Find the container whose image includes **libcrypto** at a **specific version** (e.g. `3.1.4`). Produce an SPDX SBOM with the **`bom`** CLI. Variant: remove the non-compliant container from the Deployment.

**Tasks:**
1. Identify the image tag / container with the required libcrypto version.
2. `bom generate --image <image:tag> --output report.spdx` and verify with `bom document outline`.
3. (Variant) Edit the Deployment to drop the bad container or retag the image.

**Skills:** `bom generate`, `grep` on SBOM output, `kubectl exec` + package manager, Deployment YAML.

<details>
<summary>Solution</summary>

```bash
kubectl get deploy -n <namespace> -o yaml | grep image:
# per container
kubectl get pod -n <namespace> -o jsonpath='{range .spec.containers[*]}{.name}{"\t"}{.image}{"\n"}{end}'
```

Scan each tag:

```bash
for img in repo:tag-a repo:tag-b repo:tag-c; do
  echo "=== $img ==="
  bom generate --image "$img" | grep -E 'libcrypto|3\.1\.4'
done
```

SPDX output:

```bash
bom generate --image repo:tag-b --output report.spdx
bom document outline report.spdx | grep -i libcrypto
```

Inside a running container (Alpine):

```bash
kubectl exec -n <namespace> <pod> -c <container> -- apk list | grep libcrypto
```

Remediation: `kubectl edit deployment -n <namespace>` — remove wrong container or change image tag. **Trivy** (`trivy image … | grep libcrypto`) is a useful cross-check if `bom` is slow.

</details>

---

### 3. Host hardening — `developer` user and Docker TCP

**Scenario:** Linux user `developer` must **not** be in the `docker` group. Docker must **not** accept remote TCP; keep local Unix socket (`unix:///var/run/docker.sock`).

**Tasks:**
1. Remove `developer` from group `docker`.
2. Disable TCP in Docker config and/or systemd socket unit.
3. Restart Docker; verify it is healthy and not listening on public TCP (e.g. `2375`).

**Skills:** `gpasswd`, `/etc/docker/daemon.json`, `docker.socket`, `systemctl`, file ownership.

<details>
<summary>Solution</summary>

**Remove from group:**

```bash
sudo gpasswd -d developer docker
groups developer
```

(`sudo deluser developer docker` or `usermod` if available.)

**`/etc/docker/daemon.json`** — remove TCP `hosts`; keep Unix only:

```json
{
  "hosts": ["unix:///var/run/docker.sock"]
}
```

**`/usr/lib/systemd/system/docker.socket`** (reported on exam) — remove TCP bind, e.g. drop `-H tcp://0.0.0.0:2375` from `ExecStart`. Set unit file owner to **root** if required:

```bash
sudo chown root:root /usr/lib/systemd/system/docker.socket
```

**Restart and verify:**

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker.socket
sudo systemctl restart docker
sudo systemctl status docker
ss -lntp | grep -E 'docker|2375'
```

If Docker **hangs** on restart, fix JSON syntax and ensure `daemon.json` `hosts` does not conflict with the socket unit.

</details>

---

## Additional scenarios from the thread

### 4. Falco lab — sensitive file read rule

**Scenario:** Falco is installed; default rules do not log `/dev/mem`. Write a local rule, load it, identify the container, remediate.

<details>
<summary>Solution</summary>

```yaml
# e.g. /etc/falco/rules.d/dev-mem.yaml
- rule: Dev mem access
  desc: Detect read/open on /dev/mem
  condition: open_read and fd.name = /dev/mem
  output: "dev/mem access (container=%container.name pod=%k8s.pod.name)"
  priority: WARNING
```

```bash
sudo falco -r /etc/falco/rules.d/dev-mem.yaml
# or
sudo falco -U
```

</details>

---

### 5. Trivy scan + `bom` SBOM

**Scenario:** Given images, find critical/high CVEs and a specific dependency (e.g. libcrypto/OpenSSL). State which tag must not be deployed.

<details>
<summary>Solution</summary>

```bash
trivy image --severity HIGH,CRITICAL myimage:tag
bom generate --image myimage:tag -o sbom.spdx
bom document outline sbom.spdx | grep -iE 'libcrypto|openssl'
bom generate --image myimage:tag | grep -i libcrypto
```

</details>

---

### 6. CIS benchmark — kube-bench (API server, etcd, kubelet)

**Scenario:** `kube-bench` reports FAIL items on control plane and worker (sections **1.x**, **2.x**, **4.x**). Fix only what the brief lists; restart services; re-run until PASS.

<details>
<summary>Solution</summary>

```bash
kube-bench run --targets master,node
# or
kube-bench
```

| Finding | Fix |
|--------|-----|
| Anonymous API access | `kube-apiserver.yaml`: `--anonymous-auth=false` |
| etcd data dir ownership | `useradd -r etcd` if missing; `chown -R etcd:etcd /var/lib/etcd` |
| kubelet CIS items | `/var/lib/kubelet/config.yaml` or kubelet flags per remediation text |

```bash
sudo systemctl restart kubelet
kube-bench run --targets node
```

Run with **`--targets master,node`** if kubelet section 4.x fails do not appear on master-only runs.

</details>

---

### 7. API server audit logging

**Scenario:** Mount audit policy and log file on `kube-apiserver`. Log **all Namespace** interactions at **RequestResponse** level. Variant: update rules in the policy file after enabling auditing.

<details>
<summary>Solution</summary>

`/etc/kubernetes/audit-policy.yaml`:

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: Metadata
    omitStages: ["RequestReceived"]
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["namespaces"]
```

On `kube-apiserver` static Pod:

```yaml
    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit/audit.log
```

Add hostPath volumes for policy and log directory. Verify:

```bash
kubectl get ns
sudo tail /var/log/kubernetes/audit/audit.log
```

</details>

---

### 8. ImagePolicyWebhook admission

**Scenario:** Partial webhook configuration is provided. Complete API server / admission config so image pulls are validated.

<details>
<summary>Solution</summary>

`/etc/kubernetes/admission-config.yaml`:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
  - name: ImagePolicyWebhook
    configuration:
      imagePolicy:
        kubeConfigFile: /etc/kubernetes/imagepolicywebhook.kubeconfig
        allowTTL: 30
        denyTTL: 30
        retryBackoff: 500
        defaultAllow: false
```

On `kube-apiserver`: `--admission-control-config-file=…` and add `ImagePolicyWebhook` to `--enable-admission-plugins`. Fix mounts, CA, and webhook service connectivity; test with a non-compliant image.

</details>

---

### 9. Enable admission plugins

**Scenario:** API server is missing required admission plugins (brief gives the list).

<details>
<summary>Solution</summary>

Edit `/etc/kubernetes/manifests/kube-apiserver.yaml`:

```yaml
    - --enable-admission-plugins=NodeRestriction,NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,Priority,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota
```

Use the **exact list** from the task. Wait for static Pod restart; verify flags on the running Pod.

</details>

---

### 10. Pod Security Admission (PSS/PSA)

**Scenario:** Namespace enforces **restricted** (or **baseline**) at **enforce**. A Deployment is provided; Pods do not reach **Running**. Fix the Deployment without lowering namespace enforce level.

<details>
<summary>Solution</summary>

```bash
kubectl get ns <ns> --show-labels
```

Typical Deployment fixes for **restricted**:

- `runAsNonRoot: true`, drop `privileged: true`, drop dangerous capabilities
- `allowPrivilegeEscalation: false`
- `readOnlyRootFilesystem: true` + `emptyDir` for writable paths
- Remove `hostPath` / `hostNetwork` / `hostPID`
- Compliant non-root image

If namespace was wrongly `privileged` **enforce**, correct `pod-security.kubernetes.io/enforce` per brief. Thread note: changing image to `:latest` vs digest—follow what makes the Pod pass **restricted** validation.

</details>

---

### 11. ServiceAccount token — projected volume

**Scenario A:** Mount a short-lived SA token at a custom path via **projected volume**.  
**Scenario B:** At **ServiceAccount** level, ensure the default token is **not** auto-mounted into Pods.

<details>
<summary>Solution</summary>

**A — Pod/Deployment:**

```yaml
volumes:
  - name: sa-token-volume
    projected:
      sources:
        - serviceAccountToken:
            path: token
            expirationSeconds: 3600
            audience: api
  containers:
    - name: app
      volumeMounts:
        - name: sa-token-volume
          mountPath: /var/run/secrets/custom-tokens
          readOnly: true
```

Token path: `/var/run/secrets/custom-tokens/token`.

**B — ServiceAccount:**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-sa
automountServiceAccountToken: false
```

Set `automountServiceAccountToken: false` on the Pod spec too if the brief requires no token in that Pod.

</details>

---

### 12. NetworkPolicy — default deny + selective allow

**Scenario:** Default deny all traffic in a namespace; allow only DNS, cross-namespace ingress, or specific ports per brief. Thread variant: “deny all policy with other things.”

<details>
<summary>Solution</summary>

**Default deny:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: team-a
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

**Allow DNS egress:**

```yaml
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - { protocol: UDP, port: 53 }
        - { protocol: TCP, port: 53 }
```

Add separate policies for allowed ingress (`namespaceSelector`, `podSelector`, ports). Test with debug Pods and `nc` / `curl`.

</details>

---

### 13. CiliumNetworkPolicy

**Scenario:** Cilium CNI. Allow from a specific namespace; enable authentication/encryption; allow from **host** / control plane per brief.

<details>
<summary>Solution</summary>

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-from-ns
  namespace: app
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: trusted
    - fromEntities:
        - host
        - remote-node
```

Adjust L4 ports, ICMP, and auth per brief. See [Cilium policy docs](https://docs.cilium.io/en/stable/security/policy/). Thread: formatting errors and “allow from host” were common pain points.

</details>

---

### 14. Istio — sidecar injection and STRICT mTLS

**Scenario:** Namespace needs Istio sidecars and **STRICT** mTLS (thread also mentions layer-4 / namespace-scoped policies).

<details>
<summary>Solution</summary>

```bash
kubectl label namespace foo istio-injection=enabled --overwrite
kubectl rollout restart deployment -n foo
# or force recreate pods for sidecar injection
```

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: foo
spec:
  mtls:
    mode: STRICT
```

Verify sidecars: `kubectl get pods -n foo` (check for `istio-proxy` container). Docs: [sidecar injection](https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/), [PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/).

</details>

---

### 15. Cluster upgrade — worker node only

**Scenario:** Control plane is already on target version; upgrade **one worker** with `kubeadm`.

<details>
<summary>Solution</summary>

```bash
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt-get update
sudo apt-get install -y kubeadm=1.29.2-00 kubelet=1.29.2-00 kubectl=1.29.2-00
sudo apt-mark hold kubeadm kubelet kubectl
sudo kubeadm upgrade node
sudo systemctl daemon-reload
sudo systemctl restart kubelet
kubectl uncordon <node>
```

Package versions: `apt-cache madison kubeadm`.

</details>

---

### 16. API server — disable anonymous access

**Scenario:** Anonymous unauthenticated access to the API server must be disabled.

<details>
<summary>Solution</summary>

`/etc/kubernetes/manifests/kube-apiserver.yaml`:

```yaml
    - --anonymous-auth=false
```

Wait for static Pod restart. Often the same fix as kube-bench 1.x.x.

</details>

---

### 17. etcd encryption at rest

**Scenario:** Encrypt Secrets in etcd using a provided `EncryptionConfiguration`.

<details>
<summary>Solution</summary>

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources: [secrets]
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64-32-byte-key>
      - identity: {}
```

`kube-apiserver`: `--encryption-provider-config=/etc/kubernetes/encryption-config.yaml` + volume mount. Re-encrypt existing Secrets per [Kubernetes docs](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/).

</details>

---

### 18. Ingress TLS and HTTP → HTTPS redirect

**Scenario:** NGINX Ingress; serve app over TLS with provided cert/key; redirect HTTP to HTTPS.

<details>
<summary>Solution</summary>

```bash
kubectl create secret tls app-tls --cert=tls.crt --key=tls.key -n <ns>
```

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  tls:
    - hosts: [app.example.com]
      secretName: app-tls
```

</details>

---

### 19. RuntimeClass — gVisor or Kata

**Scenario:** Pod must use sandbox runtime handler from brief.

<details>
<summary>Solution</summary>

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
---
spec:
  runtimeClassName: gvisor
```

Confirm handler on node: `crictl info`.

</details>

---

### 20. Container immutability

**Scenario:** Enforce immutable container filesystem (writable root not allowed).

<details>
<summary>Solution</summary>

```yaml
securityContext:
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  runAsNonRoot: true
  capabilities:
    drop: ["ALL"]
volumeMounts:
  - name: tmp
    mountPath: /tmp
volumes:
  - name: tmp
    emptyDir: {}
```

</details>

---

### 21. Static analysis — Dockerfile (one line only)

**Scenario:** Fix **exactly one line** for security (`USER root`, secret in `ENV`, unsafe `ADD`, etc.).

<details>
<summary>Solution</summary>

| Issue | One-line fix |
|-------|----------------|
| `USER root` | `USER nobody` or `USER 65534` |
| Secret in `ENV` | Remove/redact value in that line |
| Unsafe `ADD http://…` | `COPY` from trusted context |

Thread: `USER root` → `USER nobody` when that was the only allowed edit.

</details>

---

### 22. Static analysis — Deployment (one line only)

**Scenario:** Multiple issues (`privileged: true`, password in `env`); change **only one line**; do not delete lines if forbidden.

<details>
<summary>Solution</summary>

- Password in `env` — clear **value** only: `value: ""`
- Or `privileged: false`
- Or pin patched `image:` tag

Thread: when deletion is disallowed, clearing the password **value** (not the key) was a reported approach.

</details>

---

### 23. Platform binary verification

**Scenario:** Verify Kubernetes binaries on a node against official release artifacts.

<details>
<summary>Solution</summary>

Follow [verifying Kubernetes binaries](https://kubernetes.io/docs/setup/release/verifying-binaries/):

```bash
curl -LO "https://dl.k8s.io/release/v1.29.2/bin/linux/amd64/kubectl.sha512"
sha512sum -c kubectl.sha512
sha512sum /usr/bin/kubelet /usr/bin/kubeadm /usr/bin/kubectl
```

Replace mismatched binaries from official signed releases.

</details>

---

### 24. OPA Gatekeeper

**Scenario:** Deploy or patch `ConstraintTemplate` / `Constraint`; violating resources must be denied.

<details>
<summary>Solution</summary>

```bash
kubectl apply -f constraint-template.yaml
kubectl apply -f constraint.yaml
kubectl apply -f bad-pod.yaml    # expect deny
kubectl apply -f good-pod.yaml   # expect admit
```

Debug: `kubectl logs -n gatekeeper-system deploy/gatekeeper-controller-manager`.

</details>

---

## Suggested practice order

| Priority | # | Topics |
|----------|---|--------|
| **High** (OP + frequent) | 1–3, 6–8, 10–12, 14–16 | Falco/`/dev/mem`, `bom`, Docker TCP, kube-bench, audit, PSA, NetPol, Istio |
| **Medium** | 4–5, 9, 17–18, 21–22 | Falco lab, Trivy, admission plugins, etcd encrypt, Ingress, static analysis |
| **Environment-dependent** | 13, 23–24 | Cilium, binary verify, Gatekeeper |

---

## References

- [Falco rules](https://falco.org/docs/rules/)
- [Kubernetes audit logging](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)
- [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)
- [Istio PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/)
- [Cilium Network Policies](https://docs.cilium.io/en/stable/security/policy/)
- Thread: `Helping with understanding some Questions _ r_kubernetes.PDF`

---

*For learning only. CNCF prohibits sharing or reproducing live exam content.*
