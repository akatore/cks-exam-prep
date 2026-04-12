# Exercise 12 — Runtime Immutability

> Related: [SecurityContext skeleton](../../skeletons/securitycontext.yaml) | [README — Monitoring, Logging and Runtime Security](../../README.md#domain-6--monitoring-logging-and-runtime-security-20)

Ensure containers are immutable at runtime — read-only filesystems, no privilege escalation, and minimal capabilities.

## Tasks

1. Create a namespace called `exercise-12`
2. Create a pod named `mutable-pod` with image `nginx:1.27` and NO security context
3. Verify you CAN write files inside the container: `k exec mutable-pod -- touch /tmp/test`
4. Create a pod named `immutable-pod` that:
   - Uses image `nginx:1.27`
   - Has `readOnlyRootFilesystem: true`
   - Has `allowPrivilegeEscalation: false`
   - Drops ALL capabilities
   - Runs as non-root (runAsUser: 1000)
   - Mounts an `emptyDir` at `/tmp` and `/var/cache/nginx` (nginx needs writable dirs)
5. Verify you CANNOT write to `/etc` or `/usr` in `immutable-pod`
6. Verify nginx still works in `immutable-pod` (writable dirs are available)
7. Create a pod named `exec-denied` that prevents any executable from being installed at runtime

## Hints

- `readOnlyRootFilesystem: true` makes the entire root filesystem read-only
- Applications that need temp dirs still work with `emptyDir` volume mounts
- nginx needs writable `/tmp`, `/var/cache/nginx`, and `/var/run`
- Immutability is about preventing modification of the container's base image at runtime

## Verify

```bash
# mutable-pod — can write anywhere
k exec mutable-pod -n exercise-12 -- touch /tmp/test
# Success

# immutable-pod — cannot write to root fs
k exec immutable-pod -n exercise-12 -- touch /etc/test 2>&1
# Read-only file system

# immutable-pod — CAN write to emptyDir mounts
k exec immutable-pod -n exercise-12 -- touch /tmp/test
# Success
```

## Cleanup

```bash
k delete ns exercise-12
```

<details>
<summary>Solution</summary>

```bash
k create ns exercise-12

# Mutable pod (insecure)
k run mutable-pod -n exercise-12 --image=nginx:1.27
```

```yaml
# immutable-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: immutable-pod
  namespace: exercise-12
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: nginx
    image: nginx:1.27
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
```

```bash
k apply -f immutable-pod.yaml

# Test
k exec mutable-pod -n exercise-12 -- touch /tmp/test
k exec immutable-pod -n exercise-12 -- touch /etc/test 2>&1
k exec immutable-pod -n exercise-12 -- touch /tmp/test
```

</details>
