# Exercise 02 — CIS Benchmark

> Related: [README — Cluster Setup](../../README.md#domain-1--cluster-setup-15)

Run CIS Kubernetes Benchmark using kube-bench and fix common findings.

## Tasks

1. Install kube-bench on the control plane node (or run it as a Job)
2. Run kube-bench against the control plane: `kube-bench run --targets=master`
3. Identify at least 3 FAIL findings
4. Fix the following common issues:
   - Ensure `--anonymous-auth=false` is set on the API server
   - Ensure `--authorization-mode` does not include `AlwaysAllow`
   - Ensure `--profiling=false` is set on the API server
5. Re-run kube-bench and verify the findings are now PASS
6. Run kube-bench against a worker node: `kube-bench run --targets=node`
7. Fix: ensure kubelet has `--protect-kernel-defaults=true`

## Hints

- kube-bench as a Job: `k apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml`
- API server is a static pod — edit `/etc/kubernetes/manifests/kube-apiserver.yaml`
- kubelet config is at `/var/lib/kubelet/config.yaml`
- After editing static pod manifests, kubelet restarts the pod automatically

## Verify

```bash
# Re-run kube-bench and grep for specific checks
kube-bench run --targets=master | grep -A2 "1.2.1\|1.2.2\|1.2.18"
# Should show PASS for all three

# Check kubelet
kube-bench run --targets=node | grep -A2 "4.2.6"
```

## Cleanup

```bash
# Revert API server changes if needed (keep a backup before editing)
# Remove kube-bench Job
k delete job kube-bench -n default
```

<details>
<summary>Solution</summary>

```bash
# Run kube-bench as a Job
k apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
k logs job/kube-bench

# Fix API server — edit static pod manifest
sudo cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml.bak
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

Add/modify these flags in the `command` section:
```yaml
- --anonymous-auth=false
- --profiling=false
# Ensure --authorization-mode includes Node,RBAC (no AlwaysAllow)
- --authorization-mode=Node,RBAC
```

```bash
# Fix kubelet
sudo vi /var/lib/kubelet/config.yaml
```

Add:
```yaml
protectKernelDefaults: true
```

```bash
sudo systemctl restart kubelet

# Re-run kube-bench
kube-bench run --targets=master
kube-bench run --targets=node
```

</details>
