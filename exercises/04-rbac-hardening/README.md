# Exercise 04 — RBAC Hardening

> Related: [RBAC skeleton](../../skeletons/rbac.yaml) | [ClusterRole skeleton](../../skeletons/clusterrole.yaml) | [README — Cluster Hardening](../../README.md#domain-2--cluster-hardening-15)

Harden RBAC by applying least-privilege access. CKS goes deeper than CKA on RBAC — you must restrict, not just create.

## Tasks

1. Create a namespace called `exercise-04`
2. Create a ServiceAccount named `app-sa` in namespace `exercise-04`
3. Audit: check what permissions `app-sa` has by default
4. Create a Role named `pod-reader` that allows ONLY `get` and `list` on `pods`
5. Create a RoleBinding named `app-read-pods` binding `pod-reader` to `app-sa`
6. Verify `app-sa` can list pods but cannot create or delete them
7. Verify `app-sa` cannot list secrets (principle of least privilege)
8. Review the `system:discovery` ClusterRoleBinding — understand why it's a risk
9. Create a ClusterRole named `restricted-node-reader` that allows only `get` on `nodes` (not `list` — reduces info leakage)

## Hints

- `k auth can-i --list --as=system:serviceaccount:<ns>:<sa> -n <ns>` to see all permissions
- Default ServiceAccounts often have too many permissions via auto-mounted tokens
- Check cluster-wide bindings: `k get clusterrolebindings -o wide | grep system:`
- Denying secrets access is critical — secrets contain credentials

## Verify

```bash
# Should return "yes"
k auth can-i list pods -n exercise-04 --as=system:serviceaccount:exercise-04:app-sa

# Should return "no"
k auth can-i create pods -n exercise-04 --as=system:serviceaccount:exercise-04:app-sa

# Should return "no"
k auth can-i list secrets -n exercise-04 --as=system:serviceaccount:exercise-04:app-sa

# Should return "yes"
k auth can-i get nodes --as=system:serviceaccount:exercise-04:app-sa
```

## Cleanup

```bash
k delete ns exercise-04
k delete clusterrole restricted-node-reader
k delete clusterrolebinding restricted-node-access
```

<details>
<summary>Solution</summary>

```bash
k create ns exercise-04
k create sa app-sa -n exercise-04

# Audit current permissions
k auth can-i --list --as=system:serviceaccount:exercise-04:app-sa -n exercise-04

# Create Role — only get and list pods
k create role pod-reader -n exercise-04 \
  --verb=get,list --resource=pods

# Bind it
k create rolebinding app-read-pods -n exercise-04 \
  --role=pod-reader \
  --serviceaccount=exercise-04:app-sa

# Create ClusterRole for restricted node access
k create clusterrole restricted-node-reader \
  --verb=get --resource=nodes

k create clusterrolebinding restricted-node-access \
  --clusterrole=restricted-node-reader \
  --serviceaccount=exercise-04:app-sa

# Verify
k auth can-i list pods -n exercise-04 --as=system:serviceaccount:exercise-04:app-sa
k auth can-i create pods -n exercise-04 --as=system:serviceaccount:exercise-04:app-sa
k auth can-i list secrets -n exercise-04 --as=system:serviceaccount:exercise-04:app-sa
k auth can-i get nodes --as=system:serviceaccount:exercise-04:app-sa
```

</details>
