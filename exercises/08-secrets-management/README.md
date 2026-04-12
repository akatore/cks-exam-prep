# Exercise 08 — Secrets Management

> Related: [Secret skeleton](../../skeletons/secret.yaml) | [Encryption Config skeleton](../../skeletons/encryption-config.yaml) | [README — Minimize Microservice Vulnerabilities](../../README.md#domain-4--minimize-microservice-vulnerabilities-20)

Manage Kubernetes Secrets securely — create, consume, and enable encryption at rest.

## Tasks

1. Create a namespace called `exercise-08`
2. Create a Secret named `db-creds` with:
   - `DB_USER=admin`
   - `DB_PASS=s3cure-p4ss`
3. Create a pod named `app-pod` that consumes the secret as:
   - Environment variables
4. Create another pod named `vol-pod` that mounts the secret as files at `/etc/secrets`
5. Verify the secret values are accessible inside both pods
6. Check how secrets are stored in etcd (they're base64, not encrypted by default):
   ```bash
   ETCDCTL_API=3 etcdctl get /registry/secrets/exercise-08/db-creds [...] | hexdump -C
   ```
7. Create an EncryptionConfiguration to encrypt secrets at rest with `aescbc`
8. Configure the API server to use the EncryptionConfiguration
9. Re-create the secret and verify it's now encrypted in etcd

## Hints

- Secrets are base64-encoded, NOT encrypted by default
- EncryptionConfiguration goes in a file on the control plane node
- API server needs `--encryption-provider-config=/path/to/config`
- After enabling, re-create existing secrets: `k get secrets -A -o json | k replace -f -`

## Verify

```bash
# Secret values in pod
k exec app-pod -n exercise-08 -- env | grep DB_
k exec vol-pod -n exercise-08 -- cat /etc/secrets/DB_USER

# After encryption — etcd data should NOT show plaintext
ETCDCTL_API=3 etcdctl get /registry/secrets/exercise-08/db-creds \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key | hexdump -C | head
# Should show encrypted bytes, not "admin" or "s3cure-p4ss"
```

## Cleanup

```bash
k delete ns exercise-08
# Revert API server encryption config if needed
```

<details>
<summary>Solution</summary>

```bash
k create ns exercise-08

# Create secret
k create secret generic db-creds -n exercise-08 \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASS=s3cure-p4ss
```

```yaml
# app-pod.yaml — secrets as env vars
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  namespace: exercise-08
spec:
  containers:
  - name: app
    image: nginx:1.27
    envFrom:
    - secretRef:
        name: db-creds
```

```yaml
# vol-pod.yaml — secrets as files
apiVersion: v1
kind: Pod
metadata:
  name: vol-pod
  namespace: exercise-08
spec:
  containers:
  - name: app
    image: nginx:1.27
    volumeMounts:
    - name: secret-vol
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-vol
    secret:
      secretName: db-creds
```

```yaml
# /etc/kubernetes/enc/encryption-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
- resources:
  - secrets
  providers:
  - aescbc:
      keys:
      - name: key1
        secret: dGhpcyBpcyBhIDMyIGJ5dGUga2V5IGZvciBhZXM=
  - identity: {}
```

```bash
k apply -f app-pod.yaml
k apply -f vol-pod.yaml

# Enable encryption at rest
sudo mkdir -p /etc/kubernetes/enc
sudo cp encryption-config.yaml /etc/kubernetes/enc/

# Edit API server manifest
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
# Add: --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml
# Add volume mount for /etc/kubernetes/enc

# Wait for API server to restart, then re-create secrets
k delete secret db-creds -n exercise-08
k create secret generic db-creds -n exercise-08 \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASS=s3cure-p4ss
```

</details>
