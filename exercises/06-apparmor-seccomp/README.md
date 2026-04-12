# Exercise 06 — AppArmor and Seccomp

> Related: [AppArmor skeleton](../../skeletons/apparmor-pod.yaml) | [Seccomp skeleton](../../skeletons/seccomp-pod.yaml) | [README — System Hardening](../../README.md#domain-3--system-hardening-10)

Apply kernel-level security profiles to pods using AppArmor and Seccomp.

## Tasks

1. Create a namespace called `exercise-06`
2. Check which AppArmor profiles are loaded on a node: `cat /sys/kernel/security/apparmor/profiles`
3. Create a pod named `apparmor-pod` that:
   - Uses image `nginx:1.27`
   - Applies the `runtime/default` AppArmor profile using the security context
4. Verify the AppArmor profile is applied by checking the pod annotations
5. Create a pod named `seccomp-pod` that:
   - Uses image `nginx:1.27`
   - Uses the `RuntimeDefault` Seccomp profile
6. Create a pod named `custom-seccomp-pod` that:
   - Uses a `Localhost` Seccomp profile from `/var/lib/kubelet/seccomp/my-profile.json`
7. Verify both seccomp pods are running with the correct profiles

## Hints

- AppArmor in v1.34: use `securityContext.appArmorProfile` (GA)
- Seccomp profile types: `RuntimeDefault`, `Localhost`, `Unconfined`
- For Localhost Seccomp, the profile JSON must exist on the node at the specified path
- Check profile: `k get pod <pod> -o jsonpath='{.spec.securityContext}'`

## Verify

```bash
# AppArmor pod should be Running
k get pod apparmor-pod -n exercise-06

# Seccomp pods should be Running
k get pod seccomp-pod -n exercise-06
k get pod custom-seccomp-pod -n exercise-06

# Check seccomp profile
k get pod seccomp-pod -n exercise-06 -o jsonpath='{.spec.containers[0].securityContext.seccompProfile}'
```

## Cleanup

```bash
k delete ns exercise-06
```

<details>
<summary>Solution</summary>

```bash
k create ns exercise-06

# Check available AppArmor profiles on node
ssh <node> -- cat /sys/kernel/security/apparmor/profiles | head -20
```

```yaml
# apparmor-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-pod
  namespace: exercise-06
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    securityContext:
      appArmorProfile:
        type: RuntimeDefault
```

```yaml
# seccomp-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-pod
  namespace: exercise-06
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    securityContext:
      seccompProfile:
        type: RuntimeDefault
```

```yaml
# custom-seccomp-pod.yaml — requires profile on node
apiVersion: v1
kind: Pod
metadata:
  name: custom-seccomp-pod
  namespace: exercise-06
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: my-profile.json
```

```bash
k apply -f apparmor-pod.yaml
k apply -f seccomp-pod.yaml
k apply -f custom-seccomp-pod.yaml
```

</details>
