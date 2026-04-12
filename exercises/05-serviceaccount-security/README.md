# Exercise 05 — ServiceAccount Security

> Related: [ServiceAccount skeleton](../../skeletons/serviceaccount.yaml) | [README — Cluster Hardening](../../README.md#domain-2--cluster-hardening-15)

Harden ServiceAccounts by disabling token auto-mounting and limiting API access.

## Tasks

1. Create a namespace called `exercise-05`
2. Create a ServiceAccount named `secure-sa` with `automountServiceAccountToken: false`
3. Create a pod named `no-token-pod` using `secure-sa` — verify no token is mounted at `/var/run/secrets/kubernetes.io/serviceaccount`
4. Create a pod named `default-pod` using the `default` ServiceAccount — verify the token IS mounted
5. Check what API calls `default-pod` can make from inside the container using `curl`
6. Disable token auto-mount on the `default` ServiceAccount
7. Create a new pod `test-pod` — verify no token is mounted even though it uses `default` SA

## Hints

- `automountServiceAccountToken: false` can be set on the ServiceAccount or on the Pod spec
- Check for token: `k exec <pod> -- ls /var/run/secrets/kubernetes.io/serviceaccount/`
- From inside a pod: `curl -sk https://kubernetes.default.svc/api/v1/namespaces -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"`

## Verify

```bash
# no-token-pod should have no token
k exec no-token-pod -n exercise-05 -- ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1
# Should show "No such file or directory"

# default-pod (before SA fix) has a token
k exec default-pod -n exercise-05 -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

## Cleanup

```bash
k delete ns exercise-05
```

<details>
<summary>Solution</summary>

```yaml
# serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: secure-sa
  namespace: exercise-05
automountServiceAccountToken: false
```

```bash
k create ns exercise-05
k apply -f serviceaccount.yaml

# Pod with secure-sa (no token)
k run no-token-pod -n exercise-05 --image=nginx:1.27 \
  --overrides='{"spec":{"serviceAccountName":"secure-sa"}}'

# Pod with default SA (has token)
k run default-pod -n exercise-05 --image=nginx:1.27

# Verify
k exec no-token-pod -n exercise-05 -- ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1
k exec default-pod -n exercise-05 -- cat /var/run/secrets/kubernetes.io/serviceaccount/token

# Disable auto-mount on default SA
k patch sa default -n exercise-05 -p '{"automountServiceAccountToken": false}'

# New pod — no token even on default SA
k run test-pod -n exercise-05 --image=nginx:1.27
k exec test-pod -n exercise-05 -- ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1
```

</details>
