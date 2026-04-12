# Exercise 01 — NetworkPolicy Security

> Related: [NetworkPolicy skeleton](../../skeletons/networkpolicy.yaml) | [Deny-All skeleton](../../skeletons/networkpolicy-deny-all.yaml) | [README — Cluster Setup](../../README.md#domain-1--cluster-setup-15)

Lock down pod-to-pod traffic using NetworkPolicies. Default deny + explicit allow is the CKS pattern.

## Tasks

1. Create a namespace called `exercise-01`
2. Deploy three pods:
   - `api` with image `nginx:1.27` and label `role=api`
   - `db` with image `nginx:1.27` and label `role=db`
   - `attacker` with image `nginx:1.27` and label `role=attacker`
3. Verify all three pods can reach each other (no policies yet)
4. Create a default-deny-all NetworkPolicy named `deny-all` that blocks all ingress and egress in the namespace
5. Verify that no pod can reach any other pod
6. Create a NetworkPolicy named `allow-api-to-db` that:
   - Applies to pods with label `role=db`
   - Allows ingress only from pods with label `role=api` on port 80
7. Create a NetworkPolicy named `allow-dns` that allows all pods in the namespace to reach DNS (UDP 53)
8. Verify that `api` can reach `db`, but `attacker` cannot

## Hints

- Default deny = empty `podSelector: {}` with `policyTypes: [Ingress, Egress]` and no rules
- Always allow DNS egress (UDP 53) or nothing resolves
- Test with `k exec <pod> -- wget -qO- --timeout=2 http://<target-ip>`

## Verify

```bash
# Get db IP
DB_IP=$(k get pod db -n exercise-01 -o jsonpath='{.status.podIP}')

# api -> db: should work
k exec api -n exercise-01 -- wget -qO- --timeout=2 http://$DB_IP

# attacker -> db: should time out
k exec attacker -n exercise-01 -- wget -qO- --timeout=2 http://$DB_IP
```

## Cleanup

```bash
k delete ns exercise-01
```

<details>
<summary>Solution</summary>

```bash
k create ns exercise-01

k run api -n exercise-01 --image=nginx:1.27 --labels=role=api
k run db -n exercise-01 --image=nginx:1.27 --labels=role=db
k run attacker -n exercise-01 --image=nginx:1.27 --labels=role=attacker
```

```yaml
# deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: exercise-01
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

```yaml
# allow-api-to-db.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-db
  namespace: exercise-01
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: api
    ports:
    - protocol: TCP
      port: 80
```

```yaml
# allow-dns.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: exercise-01
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53
```

```bash
k apply -f deny-all.yaml
k apply -f allow-api-to-db.yaml
k apply -f allow-dns.yaml

DB_IP=$(k get pod db -n exercise-01 -o jsonpath='{.status.podIP}')
k exec api -n exercise-01 -- wget -qO- --timeout=2 http://$DB_IP
k exec attacker -n exercise-01 -- wget -qO- --timeout=2 http://$DB_IP
```

</details>
