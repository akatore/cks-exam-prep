# Exercise 11 — Audit Logging

> Related: [Audit Policy skeleton](../../skeletons/audit-policy.yaml) | [README — Monitoring, Logging and Runtime Security](../../README.md#domain-6--monitoring-logging-and-runtime-security-20)

Configure Kubernetes audit logging to track API calls. Critical for security investigations.

## Tasks

1. Create an audit policy file at `/etc/kubernetes/audit/policy.yaml` with these rules:
   - Log `RequestResponse` for all requests to secrets
   - Log `Metadata` for all requests to configmaps
   - Log `Request` for all changes (create, update, delete) to deployments
   - Don't log read-only requests to endpoints or events (they're noisy)
   - Default: log `Metadata` for everything else
2. Configure the API server to use the audit policy:
   - `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`
   - `--audit-log-path=/var/log/kubernetes/audit.log`
   - `--audit-log-maxage=30`
   - `--audit-log-maxbackup=10`
   - `--audit-log-maxsize=100`
3. Create a secret and verify it appears in the audit log
4. Parse the audit log to find who created the secret

## Hints

- Audit levels: `None`, `Metadata`, `Request`, `RequestResponse`
- Rules are evaluated in order — first match wins
- API server needs volume mounts for the policy file and log directory
- On the exam, you may need to create or fix an audit policy

## Verify

```bash
# After creating a secret, check the audit log
sudo cat /var/log/kubernetes/audit.log | jq 'select(.objectRef.resource=="secrets")' | tail -5

# Should show the user, verb, and secret name
sudo cat /var/log/kubernetes/audit.log | jq '{user: .user.username, verb: .verb, resource: .objectRef.resource, name: .objectRef.name}' | tail -10
```

## Cleanup

```bash
# Revert API server changes if this is a shared cluster
```

<details>
<summary>Solution</summary>

```yaml
# /etc/kubernetes/audit/policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
- "RequestReceived"
rules:
# Don't log watch/list on noisy resources
- level: None
  resources:
  - group: ""
    resources: ["endpoints", "events"]
  verbs: ["watch", "list"]

# Log full request+response for secrets
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets"]

# Log metadata for configmaps
- level: Metadata
  resources:
  - group: ""
    resources: ["configmaps"]

# Log request body for deployment changes
- level: Request
  resources:
  - group: "apps"
    resources: ["deployments"]
  verbs: ["create", "update", "patch", "delete"]

# Default: metadata for everything else
- level: Metadata
```

```bash
sudo mkdir -p /etc/kubernetes/audit
sudo mkdir -p /var/log/kubernetes
sudo cp policy.yaml /etc/kubernetes/audit/policy.yaml

# Edit API server manifest
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

Add to command:
```yaml
- --audit-policy-file=/etc/kubernetes/audit/policy.yaml
- --audit-log-path=/var/log/kubernetes/audit.log
- --audit-log-maxage=30
- --audit-log-maxbackup=10
- --audit-log-maxsize=100
```

Add volume mounts:
```yaml
volumeMounts:
- name: audit-policy
  mountPath: /etc/kubernetes/audit
  readOnly: true
- name: audit-log
  mountPath: /var/log/kubernetes
volumes:
- name: audit-policy
  hostPath:
    path: /etc/kubernetes/audit
    type: DirectoryOrCreate
- name: audit-log
  hostPath:
    path: /var/log/kubernetes
    type: DirectoryOrCreate
```

```bash
# Wait for API server to restart
sleep 30

# Create a secret to trigger audit
k create secret generic test-secret --from-literal=key=value

# Check audit log
sudo cat /var/log/kubernetes/audit.log | jq 'select(.objectRef.resource=="secrets" and .verb=="create")' | head -20
```

</details>
